# frozen_string_literal: true

module NewInvoiceable
  extend ActiveSupport::Concern

  included do
    private

    def build_temp_invoice(child, event)
      temp_invoice = Invoice.new(child:, event:, total_cost: 0)

      # We add it here so the JS can take it into account
      if event.party? &&
         Time.zone.today < event.early_bird_date
        temp_invoice.adjustments.build(change: event.early_bird_discount,
                                       reason: '早割')
      end

      temp_invoice
    end

    def get_child_data(child, event)
      @siblings = child.siblings
      @all_invoices = child.invoices.for_registration_page(event)
      @registered_slots = child.time_slots.for_registration_page(event)

      return unless @all_invoices.empty? || @all_invoices.all?(&:in_ss)

      @all_invoices = @all_invoices.to_a + [build_temp_invoice(child, event)]

      # Merch logic
      @registered_merch = @all_invoices
        .flat_map(&:registrations)
        .select { |reg| reg.registerable_type == 'MerchItem' }
        .map(&:registerable)
    end

    def get_event_data(event, child, siblings)
      @price_list = event.price_list_for(child)
      @event_slots = event.time_slots.for_registration_page(event)
      @options = event.options + event.slot_options
      @event_cost =
        child.parent.invoices.where(event_id: event.id).sum(:total_cost)
      @siblings_event_cost =
        Invoice.where(child: siblings, event_id: event.id)
               .sum(:total_cost)
      # merch logic
      @available_merch = MerchItem.where(event_name: event.name).reject(&:closed?)
      @unregistered_merch = @available_merch - (@registered_merch || [])


    end

    def old_event?(event)
      current_user.customer? && Time.zone.today > event.end_date
    end

    def old_event_redirect
      redirect_to root_path,
                  alert: '下記カレンダーよりご希望のアクティビティを' \
                         "クリックし、選択してください。\n<注意>すでに" \
                         '終了しているアクティビティは選択をしないよう' \
                         'ご注意ください。'
    end

    def orphan_redirect(child)
      redirect_to child_url(child),
                  alert: 'お子様がアクティビティに参加するには、' \
                         '保護者の同伴が必要です。'
    end

    def set_child
      child = if params[:child]
                Child.find(params[:child])
              else
                current_user.children.first
              end
      authorize child, :show?
    end
  end
end
