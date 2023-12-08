# frozen_string_literal: true

class InvoicesController < ApplicationController
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Invoice
    params[:user] ? user_index_data : child_index_data
  end

  def show
    @invoice = authorize Invoice.find(params[:id])
    show_banner_and_survey if params[:updated]
    @previous_versions = @invoice.versions.where.not(object: nil)
                                 .reorder(created_at: :desc)
                                 .reject { |v| v.reify.total_cost.zero? }
  end

  def create
    @invoice = authorize Invoice.new(invoice_params)

    if @invoice.save
      send_emails(@invoice) unless current_user.admin?
      redirect_to invoice_path(@invoice, updated: true),
                  notice: t('success', model: 'お申込', action: '追加')
    else
      redirect_to event_path(@invoice.event_id),
                  alert: t('failure', model: 'お申込', action: '追加')
    end
  end

  def update
    @invoice = authorize Invoice.find(params[:id])
    if @invoice.child.parent_id.nil?
      return redirect_to child_path(@invoice.child),
                         alert: t('.no_parent')
    end

    if params[:commit] == '' || params[:commit] == '✔'
      status_update
    else
      full_update
    end
  end

  def destroy
    @invoice = authorize Invoice.find(params[:id])
    child = @invoice.child

    if @invoice.destroy
      redirect_to invoices_path(child: child.id), notice: t('success', model: 'お申込', action: '削除')
    else
      redirect_to invoice_path(@invoice), notice: t('failure', model: 'お申込', action: '削除')
    end
  end

  def confirm
    ignore_slots = if invoice_params['slot_regs_attributes'].nil?
                     []
                   else
                     invoice_params['slot_regs_attributes'].keep_if do |_, v|
                       v['_destroy'] == '1'
                     end.to_h.transform_values do |v|
                       v['id'].to_i
                     end.values
                   end
    ignore_opts = if invoice_params['opt_regs_attributes'].nil?
                    []
                  else
                    invoice_params['opt_regs_attributes'].keep_if do |_, v|
                      v['_destroy'] == '1'
                    end.to_h.transform_values do |v|
                      v['id'].to_i
                    end.values
                  end

    @invoice = authorize Invoice.new(invoice_params)
    @new = params[:new] == 'true'

    # This makes it work??????????
    # I do not know why
    # I likely never will
    # Do not remove this line of code
    @invoice.slot_regs.each

    @invoice.calc_cost(ignore_slots, ignore_opts)
    @ss_invoices = Invoice.where(event_id: @invoice.event_id, in_ss: true, child_id: @invoice.child_id)
  end

  def confirmed
    authorize Invoice
    @invoice = nil

    render 'invoices/confirm'
  end

  def copy
    target = Child.find(params[:target])
    event = Event.find(params[:event])
    origin = Child.find(params[:origin])

    @target_invoice = authorize copy_invoice(target, event, origin)

    redirect_to invoice_path(@target_invoice),
                notice: t('success', model: 'お申込', action: '更新')
  end

  def merge
    merge_from = authorize Invoice.find(params[:merge_from])
    merge_to = Invoice.find(params[:merge_to])

    merge_invoices(merge_from, merge_to)

    merge_from.reload.destroy
    redirect_to invoice_path(merge_to), notice: t('success', model: 'お申込', action: '更新')
  end

  def seen
    @invoice = authorize Invoice.find(params[:id])
    @invoice.update(seen_at: Time.current)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def already_registered?(t_regs, o_reg)
    t_regs.any? do |t_reg|
      t_reg.registerable_id == o_reg.registerable_id && t_reg.registerable_type == o_reg.registerable_type
    end
  end

  def child_index_data
    @child = Child.find(params[:child])
    @invoices = @child.real_invoices.distinct.order(updated_at: :desc)
    @events = @child.events.includes(
      :school,
      image_attachment: %i[blob],
      avif_attachment: %i[blob]
    ).order(start_date: :desc)
  end

  def copy_invoice(target, event, origin)
    # List of registrations to copy
    og_regs = origin.invoices.where(event: event).map(&:registrations).flatten
    # Get the target's modifiable invoice, create one if none
    target_invoice = target.invoices.where(event: event).find_by(in_ss: false) || target.invoices.create(event: event)
    t_regs = target.invoices.where(event: event).reduce([]) { |a, i| a + i.registrations }

    og_regs.each do |o_reg|
      # Skip if already on target invoice or slot is closed
      next unless valid_copy?(o_reg, t_regs)

      registerable_id = if o_reg.registerable_type == 'Option' && origin.kindy != target.kindy
                          find_equivalent_id(o_reg.registerable)
                        else
                          o_reg.registerable_id
                        end

      # If not on target invoice, add registration
      target_invoice.registrations.create!(
        child: target,
        registerable_id: registerable_id,
        registerable_type: o_reg.registerable_type,
        invoice: target_invoice
      )
    end

    target_invoice.reload.save
    target_invoice
  end

  def find_equivalent_id(option)
    return option.id unless %w[arrival k_arrival departure k_departure extension k_extension].include?(option.category)

    # Switch the category to the correct one for target's kindy/elementary
    category = option.category
    equivalent_category = if category.start_with?('k_')
                            category.gsub('k_', '')
                          else
                            "k_#{category}"
                          end

    # Find and return the equivalent option's id
    option.optionable.options.find_by(name: option.name, category: equivalent_category).id
  end

  def full_update
    if @invoice.update(invoice_params)
      # FIXME: bandaid to cover for the fact that some callbacks don't
      # update the summary (adjustments, option registrations)
      @invoice.reload.calc_cost && @invoice.save
      # Only send emails on customer updates or staff confirmations
      send_emails(@invoice) if current_user.customer? || @invoice.email_sent
      redirect_to invoice_path(
        id: @invoice.id,
        updated: true
      ), notice: t('success', model: 'お申込', action: '更新')
    else
      redirect_to event_path(id: @invoice.event_id, child: @invoice.child_id),
                  status: :unprocessable_entity,
                  notice: t('failure', model: 'お申込', action: '更新')
    end
  end

  def merge_invoices(from, to)
    from.registrations.each do |reg|
      reg.update(invoice_id: to.id)
    end

    from_adj = from.adjustments
    to_adj = to.adjustments
    from_adj.each do |adj|
      next if to_adj.any? { |ta| ta.reason == adj.reason }

      to.adjustments << adj
    end

    from_coupons = from.coupons
    to_coupons = to.coupons
    from_coupons.each do |coupon|
      next if to_coupons.any? { |to_coupon| to_coupon.code == coupon.code }

      to.coupons << coupon
    end
    to.save
  end

  def parent_or_child_invoices
    invoices = if params[:user]
                 User.find(params[:user]).real_invoices
               elsif params[:child]
                 Child.find(params[:child]).real_invoices
               end
    invoices.distinct.order(updated_at: :desc)
  end

  def send_emails(invoice)
    if invoice_params['in_ss'] == 'true'
      InvoiceMailer.with(
        invoice: invoice,
        user: invoice.child.parent
      ).confirmation_notif.deliver_now
    end

    return if current_user.admin?

    send_update_emails(invoice)
  end

  def send_update_emails(invoice)
    InvoiceMailer.with(
      invoice: invoice,
      user: invoice.child.parent
    ).updated_notif.deliver_now

    InvoiceMailer.with(
      invoice: invoice,
      user: invoice.school.manager
    ).sm_updated_notif.deliver_now
  end

  def show_banner_and_survey
    @updated = true
    @surveys = Survey.where(active: true)
                     .select { |s| s.criteria_match?(@invoice.child) }
  end

  def status_update
    @child_invoices = @invoice.child.real_invoices.where(event_id: @invoice.event_id)

    if @invoice.update(invoice_params)
      @invoice.reload
      respond_to do |format|
        format.turbo_stream
      end
    else
      redirect_to invoice_path(@invoice),
                  status: :unprocessable_entity,
                  notice: t('failure', model: 'お申込', action: '更新')
    end
  end

  def valid_copy?(o_reg, t_regs)
    # Check if slot is closed (when slot reg)
    return false if o_reg.registerable_type == 'TimeSlot' && o_reg.registerable.closed?
    # Check if target already registered
    return false if already_registered?(t_regs, o_reg)

    true
  end

  def invoice_params
    params.require(:invoice).permit(
      :id, :child_id, :event_id, :in_ss, :entered, :email_sent,
      slot_regs_attributes: %i[id child_id _destroy invoice_id registerable_id
                               registerable_type],
      opt_regs_attributes: %i[id child_id _destroy invoice_id registerable_id
                              registerable_type],
      coupons_attributes: [:code],
      adjustments_attributes: %i[id reason change invoice_id _destroy]
    )
  end

  def user_index_data
    @user = User.find(params[:user])
    @children = @user.children.includes(
      :real_invoices,
      events: %i[avif_attachment image_attachment school]
    )
  end
end
