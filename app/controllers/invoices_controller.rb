# frozen_string_literal: true

class InvoicesController < ApplicationController
  include NewInvoiceable

  after_action :verify_authorized

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

    respond_to do |format|
      format.html
      format.pdf do
        send_data @invoice.pdf,
                  filename: "invoice-#{@invoice.id}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  def new
    @event = authorize Event.find(params[:event_id]), :show?
    return old_event_redirect if old_event?(@event)

    @child = set_child
    return orphan_redirect(@child) if @child.parent_id.nil?

    get_child_data(@child, @event)
    get_event_data(@event, @child, @siblings)
  end

  def create
    @invoice = authorize Invoice.new(permitted_attributes(Invoice))

    if @invoice.save
      send_emails(@invoice) unless current_user.admin?
      redirect_to invoice_path(@invoice, updated: true),
                  notice: t('success', model: 'お申込', action: '追加')
    else
      redirect_to new_invoice_path(event_id: @invoice.event_id, child: @invoice.child_id),
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
      redirect_to invoices_path(child: child.id),
                  notice: t('success', model: 'お申込', action: '削除')
    else
      redirect_to invoice_path(@invoice),
                  notice: t('failure', model: 'お申込', action: '削除')
    end
  end

  def confirm
    @invoice = authorize Invoice.new(permitted_attributes(Invoice))
    @invoice.calc_cost
    @ss_invoices = Invoice.where(event_id: @invoice.event_id, in_ss: true,
                                 child_id: @invoice.child_id)
    @new = params[:new] == 'true'
    

    # Temp redirect while working on the registration page refactor
    render params[:rework] ? 'invoices/_confirm_rework' : 'invoices/confirm'
  end

  def copy
    target = authorize(Child.find(params[:target]), :show?)
    event = authorize(Event.find(params[:event]), :show?)
    origin = authorize(Child.find(params[:origin]), :show?)

    @target_invoice = copy_invoice(target, event, origin)

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
    @child = authorize Child.find(params[:child]), :show?
    @invoices = @child.invoices.distinct.order(updated_at: :desc)
    @events = @child.events.includes(
      :school,
      image_attachment: %i[blob],
      avif_attachment: %i[blob]
    ).order(start_date: :desc)
  end

  def copy_invoice(target, event, origin)
    # List of registrations to copy
    og_regs = origin.invoices.where(event:).map(&:registrations).flatten
    # Get the target's modifiable invoice, create one if none
    target_invoice = target.invoices.where(event:).find_by(in_ss: false) || target.invoices.create(event:)
    t_regs = target.invoices.where(event:).reduce([]) { |a, i| a + i.registrations }

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
        registerable_id:,
        registerable_type: o_reg.registerable_type,
        invoice: target_invoice
      )
    end

    target_invoice.reload.save
    target_invoice
  end

  def find_equivalent_id(option)
    return option.id unless %w[arrival k_arrival departure k_departure extension
                               k_extension].include?(option.category)

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
    if @invoice.update(permitted_attributes(@invoice))
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
      redirect_to new_invoice_path(event_id: @invoice.event_id, child: @invoice.child_id),
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
    if permitted_attributes(@invoice)['in_ss'] == 'true'
      InvoiceMailer.with(
        invoice:,
        user: invoice.child.parent
      ).confirmation_notif.deliver_later
      return
    end

    # Don't let parents know when we're fixing stuff
    # Or an invoice needs to be unconfirmed for changes
    # They'll be notified when the changes are made
    return if current_user.admin? ||
              permitted_attributes(@invoice)['in_ss'] == 'false'

    send_update_emails(invoice)
  end

  def send_update_emails(invoice)
    InvoiceMailer.with(
      invoice:,
      user: invoice.child.parent
    ).updated_notif.deliver_later

    InvoiceMailer.with(
      invoice:,
      user: invoice.school.manager
    ).sm_updated_notif.deliver_later
  end

  def show_banner_and_survey
    @updated = true
    @surveys = Survey.where(active: true)
                     .select { |s| s.criteria_match?(@invoice.child) }
  end

  def status_update
    @child_invoices = @invoice.child.real_invoices.where(event_id: @invoice.event_id)

    if @invoice.update(permitted_attributes(@invoice))
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

  def user_index_data
    @user = authorize User.find(params[:user]), :show?
    @children = @user.children.includes(
      :real_invoices,
      events: %i[avif_attachment image_attachment school]
    )
  end
end
