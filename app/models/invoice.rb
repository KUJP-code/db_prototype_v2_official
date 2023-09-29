# frozen_string_literal: true

require 'prawn/measurement_extensions'

# Handles data for customer Invoices
class Invoice < ApplicationRecord
  before_save :update_regs_child, :calc_cost

  belongs_to :child
  delegate :parent, to: :child
  delegate :school, to: :child
  belongs_to :event

  has_many :registrations, dependent: :destroy
  accepts_nested_attributes_for :registrations
  has_many :slot_regs, -> { where(registerable_type: 'TimeSlot') },
           class_name: 'Registration',
           dependent: :destroy,
           inverse_of: :invoice
  accepts_nested_attributes_for :slot_regs, allow_destroy: true
  has_many :opt_regs, -> { where(registerable_type: 'Option') },
           class_name: 'Registration',
           dependent: :destroy,
           inverse_of: :invoice
  accepts_nested_attributes_for :opt_regs, allow_destroy: true,
                                           reject_if: :orphan_option
  has_many :time_slots, through: :slot_regs,
                        source: :registerable,
                        source_type: 'TimeSlot'
  has_many :options, through: :opt_regs,
                     source: :registerable,
                     source_type: 'Option'
  has_many :adjustments, dependent: :destroy
  accepts_nested_attributes_for :adjustments, allow_destroy: true
  has_many :coupons, as: :couponable,
                     dependent: :destroy
  accepts_nested_attributes_for :coupons, reject_if: :blank_or_dup

  # Track changes with Paper Trail
  has_paper_trail unless: proc { |t| t.in_ss || t.seen_at || t.entered || t.email_sent }

  # Allow export/import with postgres-copy
  acts_as_copy_target

  # Scopes
  # Only invoices with at least one time slot registered
  scope :real, -> { where('slot_regs_count > 0') }

  # Validations
  validates :total_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def calc_cost(ignore_slots = [], ignore_opts = [])
    @ignore_slots = ignore_slots
    @ignore_opts = ignore_opts
    @breakdown = +''
    course_cost = calc_course_cost
    option_cost = calc_option_cost
    adjustments = calc_adjustments
    generate_details

    calculated_cost = course_cost + adjustments + option_cost
    calculated_cost = 0 if calculated_cost.negative?
    update_cost(calculated_cost)
  end

  def pdf
    pdf = Prawn::Document.new
    pdf.font_families.update(
      'NotoSans' => {
        normal: Rails.root.join('app/assets/fonts/NotoSansJP-Medium.ttf')
      }
    )
    pdf.font('NotoSans')
    pdf.define_grid(columns: 20, rows: 20)
    pdf_header(pdf)
    pdf_summary(pdf)
    pdf_footer(pdf)
    pdf.render
  end

  def id_and_cost
    "##{id}, #{yenify(total_cost)}"
  end

  private

  # Recursively finds the next largest course for given number of registrations
  # The 30 and 35 can be hardcoded since I'm told the number of courses
  # doesn't change
  def best_price(num_regs, courses)
    return 0 if num_regs.zero?

    if num_regs >= 55
      @breakdown << "<p>- 50回コース: #{yenify(courses['50'])}</p>"
      return courses['50'] + best_price(num_regs - 50, courses)
    end

    course = nearest_five(num_regs)
    cost = courses[course.to_s]

    @breakdown << "<p>- #{course}回コース: #{yenify(cost)}</p>" unless cost.nil?
    return cost + best_price(num_regs - course, courses) unless num_regs < 5

    return spot_use(num_regs, courses) unless child.member? && niche_case?

    pointless_price(num_regs, courses)
  end

  def blank_or_dup(coupon)
    return true if coupon['code'].nil? || coupons.map(&:code).include?(coupon['code'])

    false
  end

  def calc_adjustments
    return 0 unless adjustments.size.positive? || needs_hat? || first_time? || repeater?

    @breakdown << '<h4 class="fw-semibold">調整:</h4>'
    @breakdown << '<div class="d-flex flex-column align-items-start gap-1">'
    hat_adjustment if needs_hat?
    first_time_adjustment if first_time?
    repeater_discount if repeater?
    generic_adj = adjustments.reduce(0) { |sum, adj| sum + adj.change }
    adjustments.each do |adj|
      @breakdown << "<p>#{adj.reason}: #{yenify(adj.change)}</p>"
    end
    @breakdown << '</div>'

    generic_adj
  end

  def calc_course_cost
    num_regs = slot_regs.size - @ignore_slots.size
    course_cost = if child.member?
                    best_price(num_regs, member_prices)
                  else
                    best_price(num_regs, non_member_prices)
                  end

    snack_count = slot_regs.count do |reg|
      !reg._destroy && reg.registerable.snack
    end
    snack_cost = snack_count * 165

    # Needs to be filter_map because next in #map returns nil
    extra_cost_slots = slot_regs.filter_map do |reg|
      slot = reg.registerable

      next if reg._destroy
      next if child.external? && slot.ext_modifier.zero?
      next if child.internal? && slot.int_modifier.zero?

      slot
    end

    extra_cost = extra_cost_slots.reduce(0) do |sum, slot|
      child.external? ? sum + slot.ext_modifier : sum + slot.int_modifier
    end

    course_cost += extra_cost + snack_cost

    @breakdown << '</div>'
    @breakdown.prepend(
      "<h4 class='fw-semibold'>コース:</h4>
      <div class='d-flex flex-column align-items-start gap-1'>
      <p>#{yenify(course_cost)} (#{num_regs}回)</p>
      <p>追加料金 x #{extra_cost_slots.size}: #{yenify(extra_cost)}</p>
      <p>午後コースおやつ代 x #{snack_count}: #{yenify(snack_cost)}</p>"
    )
    course_cost
  end

  def calc_option_cost
    # Prevent multiple siblings registering for same event option
    check_event_opts
    # Ignore options to be deleted on confirmation screen
    opt_cost = opt_regs.reject do |reg|
                 @ignore_opts.include?(reg.id)
               end.reduce(0) { |sum, reg| sum + reg.registerable.cost }
    @breakdown << "<h4 class='fw-semibold'>オプション:</h4>
                   <div class='d-flex flex-column align-items-start gap-1'>
                   <p>#{yenify(opt_cost)} (#{opt_regs.count { |r| r.registerable.name != 'なし' } - @ignore_opts.size}オプション)<p>"

    # Find the options on this invoice, even if not saved
    temp_opts = {}
    opt_regs.each do |reg|
      next if @ignore_opts.include?(reg.id)

      opt = reg.registerable
      next if opt.name == 'なし'

      if temp_opts[opt.name].nil?
        temp_opts[opt.name] = {
          cost: opt.cost,
          count: 1
        }
      else
        temp_opts[opt.name][:count] += 1
        temp_opts[opt.name][:cost] += opt.cost
      end
    end
    # Display options with count and cost
    temp_opts.each do |name, _|
      @breakdown << "<p>- #{name} x #{temp_opts[name][:count]}: #{yenify(temp_opts[name][:cost])}</p>"
    end

    @breakdown << '</div>'
    opt_cost
  end

  def check_event_opts
    opt_regs.where(registerable_id: event.options.ids, registerable_type: 'Option').find_each do |reg|
      reg.destroy if child.siblings.any? { |s| s.options.include?(reg.registerable) }
    end
  end

  def first_time?
    child.external? && child.first_seasonal
  end

  def first_time_adjustment
    registration_cost = 1_100
    reason = '初回登録料(初めてシーズナルスクールに参加する非会員の方)'
    return if adjustments.any? { |adj| adj.change == registration_cost && adj.  reason == reason } ||
              child.adjustments.any? { |adj| adj.change == registration_cost && adj.reason == reason }

    adjustments.new(change: registration_cost, reason: reason)
  end

  def full_days(slot_ids)
    TimeSlot.all.where(event_id: event_id, id: slot_ids, morning_slot_id: slot_ids).where.not(category: :special).size
  end

  def generate_details
    @breakdown.prepend(
      "<div class='d-flex gap-3 flex-column align-items-start'>\n
      <h2 class='fw-semibold'>#{child.name}</h2>\n
      <h4 class-'fw-semibold'>#{child.kindy ? '幼児' : '小学生'}</h4>\n
      <h4 class-'fw-semibold'>#{case child.category
                                when 'internal'
                                    '通学生'
                                when 'reservation'
                                    '予約生'
                                else
                                    '非会員'
                                end}</h4>\n
      <h3 class='fw-semibold'>#{event.name} @ #{event.school.name}</h3>\n"
    )
    @breakdown << "</div><h2 class='fw-semibold text-start'>お申込内容:</h2>\n"

    e_opt_regs = opt_regs.where(registerable: event.options)
    unless e_opt_regs.empty?
      @breakdown << "<h4 class='fw-semibold text-start'>イベントのオプション:</h4>\n"
      @breakdown << '<div class="d-flex gap-3 p-3 justify-content-start flex-wrap">'
      event.options.each do |opt|
        @breakdown << "<p>- #{opt.name}: #{yenify(opt.cost)}</p>\n"
      end
      @breakdown << '</div>'
    end

    @breakdown << "<h4 class='fw-semibold text-start'>登録</h4>\n"
    @breakdown << '<div class="d-flex flex-column gap-3 p-3 justify-content-start flex-wrap">'
    slot_regs.sort_by { |r| r.registerable.start_time }.each do |slot_reg|
      next if @ignore_slots.include?(slot_reg.id)

      slot = slot_reg.registerable

      @breakdown << if slot.morning
                      "<div class='slot_regs d-flex flex-wrap gap-3 text-start'><h5>#{slot.name} (#{slot.date})</h5>\n"
                    else
                      "<div class='slot_regs d-flex flex-wrap gap-3 text-start'><h5>#{slot.name} (#{slot.date}) (午後)</h5>\n"
                    end

      # Show details for all registered options, even unsaved
      opt_regs.select { |reg| slot.options.ids.include?(reg.registerable_id) }.each do |opt_reg|
        next if opt_reg.nil? || @ignore_opts.include?(opt_reg.id)

        opt = opt_reg.registerable
        next if opt.name == 'なし'

        @breakdown << "<p> - #{opt.name}: #{yenify(opt.cost)}</p>\n"
      end
      @breakdown << '</div>'
    end
    @breakdown << '</div>'
  end

  def hat_adjustment
    hat_cost = 1_100
    hat_reason = '帽子代(野外アクティビティに参加される方でKids UP帽子をお持ちでない方のみ)'
    return if hat_adj_exists(hat_cost, hat_reason)

    adjustments.new(change: hat_cost, reason: hat_reason)
  end

  def hat_adj_exists(hat_cost, hat_reason)
    adjustments.any? { |adj| adj.change == hat_cost && adj.reason == hat_reason } ||
      child.adjustments.any? { |adj| adj.change == hat_cost && adj.reason == hat_reason }
  end

  def member_prices
    event.member_prices.courses
  end

  # This one actually refers to the child needing a hat or not
  def needs_hat?
    return false if child.received_hat || child.internal?

    # They only need one if registered for an outdoor activity now
    slot_regs.any? { |reg| reg.registerable.category == 'outdoor' }
  end

  # Decides if we need to apply the dumb 200 円 increase
  def niche_case?
    slot_regs.size - @ignore_slots.size < 5 && child.kindy && full_days(slot_regs.map(&:registerable_id)).positive?
  end

  def non_member_prices
    event.non_member_prices.courses
  end

  # Finds the nearest multiple of 5 to the passed integer
  # Because courses are in multiples of 5, other than spot use
  def nearest_five(num)
    (num / 5).floor(0) * 5
  end

  # Remove options where the slot is no longer registered for
  def orphan_option(opt_reg)
    # Exclude event options from the check
    return false if event.options.ids.include?(opt_reg['registerable_id'].to_i)

    option = Option.find(opt_reg['registerable_id'])
    # Allow the pizza party 'option' to be chosen without a corresponding activity
    return false if option.name == 'ティーチャーみずきとのピザパーティ'
    # If for special day extension, only delete if neither registered
    return slot_regs.none? { |r| r.registerable.special? } if option.extension? || option.k_extension?

    slot_regs.none? { |s_reg| s_reg.registerable_id == option.optionable_id }
  end

  def pdf_footer(pdf)
    tax = yenify(0.1 * total_cost)
    without_tax = yenify(0.9 * total_cost)

    # Tax box
    pdf.grid([18, 0], [18, 2]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 29.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('税率区分', align: :center, color: 'ffffff') }
    end

    pdf.grid([18, 3], [18, 5]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 29.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('消費税', align: :center, color: 'ffffff') }
    end

    pdf.grid([18, 6], [18, 8]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 29.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('金額（税抜）', align: :center, color: 'ffffff') }
    end

    pdf.grid([19, 0], [19, 2]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text('10%対象', align: :center, color: '000000') }
    end

    pdf.grid([19, 3], [19, 5]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text(tax, align: :center, color: '000000') }
    end

    pdf.grid([19, 6], [19, 8]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text(without_tax, align: :center, color: '000000') }
    end

    # Summary box
    pdf.grid([17, 12], [17, 15]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 38.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('小計', align: :center, color: 'ffffff') }
    end

    pdf.grid([18, 12], [18, 15]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 38.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('消費税', align: :center, color: 'ffffff') }
    end

    pdf.grid([19, 12], [19, 15]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 38.mm, 13.mm)
      pdf.pad(4.mm) { pdf.text('合計', align: :center, color: 'ffffff') }
    end

    pdf.grid([17, 16], [17, 19]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text(without_tax, align: :center, color: '000000') }
    end

    pdf.grid([18, 16], [18, 19]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text(tax, align: :center, color: '000000') }
    end

    pdf.grid([19, 16], [19, 19]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(4.mm) { pdf.text(yenify(total_cost), align: :center, color: '000000') }
    end
  end

  def pdf_header(pdf)
    # Title
    pdf.grid([0, 0], [1, 19]).bounding_box do
      pdf.fill_color '2864f0'
      pdf.fill_rectangle(pdf.bounds.top_left, 191.mm, 1.cm)
      pdf.pad(1.mm) { pdf.text('領収書', align: :center, color: 'ffffff', size: 20) }
    end

    # Total Cost
    pdf.grid([1, 0], [1, 9]).bounding_box do
      pdf.pad(2.mm) { pdf.text("#{child.parent.name}様 御中", size: 20, color: '000000') }
    end
    pdf.grid([2, 0], [2, 9]).bounding_box do
      pdf.stroke_bounds
      pdf.fill_rectangle(pdf.bounds.top_left, 95.mm, 13.mm)
      pdf.pad(3.mm) { pdf.text('金額（税込）', align: :center, color: 'ffffff', size: 20) }
    end
    pdf.grid([3, 0], [4, 9]).bounding_box do
      pdf.stroke_bounds
      pdf.pad(9.mm) { pdf.text(yenify(total_cost), align: :right, color: '000000', size: 20) }
    end

    # Date & Registration number
    pdf.grid([1, 11], [2, 19]).bounding_box do
      pdf.text("発行日: #{Time.zone.now.strftime('%F')}", align: :right, color: '000000')
      pdf.text('登録番号: T7-0118-0103-7173', align: :right, color: '000000')
    end

    # Company Info
    pdf.grid([2, 11], [6, 19]).bounding_box do
      pdf.text("株式会社Kids-UP\n" \
               "〒120-0034\n" \
               "住所：東京都足立区千住\n" \
               "1-4-1東京芸術センター11階\n" \
               "電話：03-3870-0099\n",
               color: '000000',
               leading: 2.mm,
               size: 14)
    end
  end

  def pdf_summary(pdf)
    pdf.grid([6, 0], [16, 19]).bounding_box do
      pdf.stroke_bounds
      pdf.text 'This will be the summary section soon!'
    end
  end

  # Calculates how many times we need to apply the dumb 200円 increase
  def pointless_price(num_regs, courses)
    days = full_days(slot_regs.map(&:registerable_id))
    extension_cost = days * (courses['1'] + 200)
    @breakdown << "<p>スポット1回(13:30~18:30) x #{days}: #{yenify(extension_cost)}円</p>\n"
    spot_cost = spot_use(num_regs - days, courses)
    extension_cost + spot_cost
  end

  def repeater?
    child.external? && child.first_seasonal == false && slot_regs.size - @ignore_slots.size > 9
  end

  def repeater_discount
    discount = -10_000
    reason = '非会員リピーター割引(以前シーズナルスクールに参加された非会員の方)'
    return if adjustments.any? { |adj| adj.change == discount && adj.reason == reason } || child.invoices.where(event: event).any? do |invoice|
                  invoice.adjustments.find_by(change: discount, reason: reason)
                end

    adjustments.new(change: discount, reason: reason)
  end

  def spot_use(num_regs, courses)
    spot_cost = num_regs * courses['1']
    @breakdown << "<p>スポット1回(午前・15:00~18:30) x #{num_regs}: #{yenify(spot_cost)}</p>\n" unless spot_cost.zero?
    spot_cost
  end

  # Updates total cost and summary once calculated/generated
  def update_cost(new_cost)
    self.total_cost = new_cost
    @breakdown << "<h2 id='final_cost' class='fw-semibold text-start'>合計（税込）: #{yenify(new_cost)}</h2>\n
    <p class='text-start'>登録番号: T7-0118-0103-7173</p>"
    self.summary = @breakdown
  end

  def update_regs_child
    return if registrations.empty? || registrations.first.child_id == child_id

    registrations.each do |reg|
      reg.update!(child_id: child_id)
    end
  end

  def yenify(number)
    "#{number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}円"
  end
end
