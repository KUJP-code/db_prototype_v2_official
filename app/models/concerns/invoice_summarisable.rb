# frozen_string_literal: true

module InvoiceSummarisable
  extend ActiveSupport::Concern

  included do
    private

    def generate_summary(data)
      "#{header}
       #{course_summary(data) if data[:num_regs].positive?}
       #{option_summary(data) if data[:options].any?}
       #{merch_summary(data) if data[:merch_items].any?}
       #{adjustment_summary if adjustments.size.positive?}
       #{slot_details(data[:time_slots])}
       <h2 id='final_cost' class='fw-semibold text-start'>
         合計（税込）: #{yenify(data[:total_cost])}
       </h2>"
    end

    def yenify(number)
      "#{number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}円"
    end
  end

  def header
    "<div class='d-flex gap-3 flex-column align-items-start'>\n
      <h4 class-'fw-semibold'>#{child.kindy ? '幼児' : '小学生'}</h4>\n
      <h4 class-'fw-semibold'>#{I18n.t("children.child.#{child.category}")}</h4>\n
      <h3 class='fw-semibold'>#{event.name} @ #{event.school.name}</h3>\n
    </div>"
  end

  def course_summary(data)
    return party_summary(data) if event.party?

    seasonal_summary(data)
  end

  def seasonal_summary(data)
    extra_cost = if data[:extra_cost].positive?
                   "<p>追加料金 x #{data[:extra_cost_count]}: #{yenify(data[:extra_cost])}</p>\n"
                 else
                   ''
                 end
    snack_cost = if data[:snack_cost].positive?
                   "<p>午後コースおやつ代 x #{data[:snack_count]}: #{yenify(data[:snack_cost])}</p>\n"
                 else
                   ''
                 end
    "<div class='d-flex flex-column align-items-start gap-1'>
        <h4 class='fw-semibold'>コース:</h4>
        <p>#{yenify(data[:course_cost])} (#{data[:num_regs]}回)</p>
        #{data[:course_summary]}\n
        #{extra_cost}
        #{snack_cost}
    </div>"
  end

  def party_summary(data)
    "<div class='d-flex flex-column align-items-start gap-1'>
        <p>イベント x #{data[:num_regs]}: #{yenify(data[:course_cost])}</p>
    </div>"
  end

  def option_summary(data)
    "<div class='d-flex flex-column align-items-start gap-1'>
       <h4 class='fw-semibold'>オプション:</h4>
       <p>#{yenify(data[:opt_cost])} (#{data[:options].size}オプション)<p>
          #{per_name_summary(data[:options])}\n
     </div>"
  end

  def merch_summary(data)
    return '' unless data[:merch_items].any?

    per_name_costs = data[:merch_items].group(:name).sum(:cost)
    per_name_counts = data[:merch_items].group(:name).count

    summary_lines = per_name_counts.map do |name, count|
      "<p>- #{name} x #{count}: #{yenify(per_name_costs[name])}</p>"
    end.join

    "<div class='d-flex flex-column align-items-start gap-1'>
      <h4 class='fw-semibold'>グッズ:</h4>
      <p>#{yenify(data[:merch_cost])} (#{data[:merch_items].size}点)</p>
      #{summary_lines}
    </div>"
  end

  def per_name_summary(opts)
    per_name_costs = opts.group(:name).sum(:cost)
    per_name_counts = opts.group(:name).count

    per_name_counts.map do |name, count|
      "<p>- #{name} x #{count}: #{yenify(per_name_costs[name])}</p>\n"
    end.join
  end

  def adjustment_summary
    "<h4 class='fw-semibold text-start'>調整:</h4>
     <div class='d-flex flex-column align-items-start gap-1'>
       #{adjustments.map { |adj| "<p>#{adj.reason}: #{yenify(adj.change)}</p>\n" }.join}
     </div>"
  end

  def slot_details(slots)
    registered_opts = @data[:options].map(&:id)
    "<h4 class='fw-semibold text-start'>登録</h4>\n
     <div class='d-flex flex-column gap-3 justify-content-start flex-wrap'>
       #{slots.order(start_time: :asc).map { |slot| detailed_slot(slot, registered_opts) }.join}
    </div>"
  end

  def detailed_slot(slot, registered_opts)
    afternoon_text = slot.morning ? '' : ' (午後)'
    ja_days = { 'Sunday' => '日', 'Monday' => '月',
                'Tuesday' => '火', 'Wednesday' => '水',
                'Thursday' => '木', 'Friday' => '金',
                'Saturday' => '土' }.freeze
    ja_day = ja_days[slot.start_time.strftime('%A')]
    date = "#{slot.start_time.strftime('%m月%d日')} #{ja_day}"

    "<div class='slot_regs d-flex flex-wrap gap-3 text-start'>
      <h5>#{slot.name} (#{date}) #{afternoon_text}</h5>
      #{detailed_slot_options(slot, registered_opts).join}\n
    </div>"
  end

  def detailed_slot_options(slot, registered_opts)
    slot.options
        .select { |o| registered_opts.include?(o.id) }
        .map do |opt|
      "<p> - #{opt.name}: #{yenify(opt.cost)}</p>\n"
    end
  end
end
