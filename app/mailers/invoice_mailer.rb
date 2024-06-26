# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  before_action :set_shared_vars

  def confirmation_notif
    attachments['invoice.pdf'] = @invoice.pdf
    mail(to: @parent.email, subject: t('.invoice_confirm'))
  end

  def updated_notif
    if @updater && @parent.id == @updater.id
      mail(to: @parent.email, subject: t('.booking_made'))
    else
      mail(to: @parent.email, subject: t('.invoice_updated'))
    end
  end

  def sm_updated_notif
    @recipients = @invoice.school.managers.pluck(:email) || ['h-leroy@kids-up.jp']
    mail(to: @recipients, subject: t('.invoice_updated'))
  end
end

private

def set_shared_vars
  @invoice = params[:invoice]
  @child = @invoice.child
  @updater = find_updater
  @parent = @child.parent
end

def find_updater
  return nil if @invoice.versions.empty?
  return nil if @invoice.versions.last.whodunnit.nil?

  User.find(@invoice.versions.last.whodunnit)
end
