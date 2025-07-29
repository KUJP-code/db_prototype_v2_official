# frozen_string_literal: true

module InvoiceCalculatable
  extend ActiveSupport::Concern
  include AdjustmentCalculator
  include CourseCalculator
  include OptionCalculator

  included do
    def generate_data
      @data = { options: validated_options,
                time_slots: validated_slots,
                merch_items: validated_merch_items }

      @data[:num_regs] = @data[:time_slots].size
      calc_course_cost(@data[:time_slots])
      calc_option_cost(@data[:options])
      calc_merch_cost(@data[:merch_items])

      adj_cost = calc_adjustments(@data[:num_regs])

      calculated_cost = @data[:course_cost] + adj_cost + @data[:opt_cost] + @data[:merch_cost]
      calculated_cost = 0 if calculated_cost.negative?

      @data[:total_cost] = calculated_cost
      @data
    end
  end

  def validated_options
    valid_reg_ids = opt_regs.reject do |reg|
      reg.marked_for_destruction? || orphan_option?(reg)
    end.map(&:registerable_id)

    Option.where(id: valid_reg_ids)
  end

  def validated_slots
    valid_reg_ids = slot_regs.reject(&:marked_for_destruction?)
                             .map(&:registerable_id)

    TimeSlot.where(id: valid_reg_ids).includes(:options)
  end

  def validated_merch_items
    valid_reg_ids = merch_regs.reject(&:marked_for_destruction?)
                              .map(&:registerable_id)
    MerchItem.where(id: valid_reg_ids)
  end

  def calc_merch_cost(items)
    @data[:merch_cost] = items.sum(&:cost)
  end
end
