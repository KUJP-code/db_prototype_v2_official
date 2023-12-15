# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'staff for InvoicePolicy' do
  it { is_expected.to authorize_action(:destroy) }
  it { is_expected.to authorize_action(:confirm) }
  it { is_expected.to authorize_action(:copy) }
  it { is_expected.to authorize_action(:merge) }
  it { is_expected.to authorize_action(:seen) }
end

RSpec.shared_examples 'an authorized user for InvoicePolicy' do
  it { is_expected.to authorize_action(:index) }
  it { is_expected.to authorize_action(:show) }
  it { is_expected.to authorize_action(:new) }
  it { is_expected.to authorize_action(:create) }
  it { is_expected.to authorize_action(:edit) }
  it { is_expected.to authorize_action(:update) }
  it { is_expected.to authorize_action(:confirmed) }
end

RSpec.shared_examples 'an unauthorized user for InvoicePolicy' do
  it { is_expected.to authorize_action(:index) }
  it { is_expected.not_to authorize_action(:show) }
  it { is_expected.to authorize_action(:new) }
  it { is_expected.not_to authorize_action(:create) }
  it { is_expected.not_to authorize_action(:edit) }
  it { is_expected.not_to authorize_action(:update) }
  it { is_expected.not_to authorize_action(:destroy) }
  it { is_expected.not_to authorize_action(:confirm) }
  it { is_expected.not_to authorize_action(:copy) }
  it { is_expected.not_to authorize_action(:merge) }
  it { is_expected.not_to authorize_action(:seen) }
end

describe InvoicePolicy do
  subject(:policy) { described_class.new(user, invoice) }

  let(:invoice) { create(:invoice) }

  context 'when admin' do
    let(:user) { build(:admin) }

    it_behaves_like 'an authorized user for InvoicePolicy'
  end

  context 'when area manager' do
    let(:user) { build(:area_manager) }

    it_behaves_like 'an authorized user for InvoicePolicy'
  end

  context 'when school manager' do
    let(:user) { build(:school_manager) }

    it_behaves_like 'an authorized user for InvoicePolicy'
  end

  context 'when statistician' do
    let(:user) { build(:statistician) }

    it_behaves_like 'an unauthorized user for InvoicePolicy'
  end

  context 'when parent of invoice child' do
    let(:user) { create(:customer) }

    before do
      user.children << invoice.child
      user.save
    end

    it_behaves_like 'an authorized user for InvoicePolicy'
  end

  context 'when parent of different child' do
    let(:user) { create(:customer) }

    it_behaves_like 'an unauthorized user for InvoicePolicy'
  end

  context 'when resolving scopes' do
    let(:invoices) { create_list(:invoice, 3) }

    it 'resolves admin to all invoices' do
      user = build(:admin)
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq(invoices)
    end

    it 'resolves area_manager to area invoices' do
      user = create(:area_manager)
      user.managed_areas << create(:area)
      school = create(:school, area: user.managed_areas.first)
      event = create(:event, school: school)
      area_invoices = create_list(:invoice, 2, event: event)
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq(area_invoices)
    end

    it 'resolves school_manager to school invoices' do
      user = create(:school_manager)
      user.managed_schools << create(:school)
      event = create(:event, school: user.managed_schools.first)
      school_invoices = create_list(:invoice, 2, event: event)
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq(school_invoices)
    end

    it 'resolves statistician to nothing' do
      user = create(:statistician)
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq(Invoice.none)
    end

    it 'resolves parent of children to child invoices' do
      user = create(:customer)
      user.children << create_list(:child, 2, invoices: [create(:invoice)])
      user.save
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq(user.invoices)
    end

    it 'resolves parent with no children to empty relation' do
      user = create(:customer)
      expect(Pundit.policy_scope!(user, Invoice.all)).to eq([])
    end
  end
end