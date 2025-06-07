require 'rails_helper'

RSpec.describe SyncWorker, type: :worker do
  let(:contact) { create(:contact) }
  let(:worker) { SyncWorker.new }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'with successful sync' do
      it 'successfully syncs contact to salesforce' do
        expect {
          worker.perform(contact.id, 'CREATE', 'salesforce')
        }.not_to raise_error

        expect(Rails.logger).to have_received(:info)
          .with("Successfully synced contact #{contact.id} to salesforce")
      end
    end

    context 'with unknown CRM' do
      it 'raises error for unknown CRM provider' do
        expect {
          worker.perform(contact.id, 'CREATE', 'unknown_crm')
        }.to raise_error('Unknown CRM: unknown_crm')
      end
    end

    context 'with missing contact' do
      it 'raises error when contact not found' do
        expect {
          worker.perform(999, 'CREATE', 'salesforce')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#transform_for_crm' do
    it 'transforms data for salesforce' do
      data = worker.send(:transform_for_crm, contact, 'salesforce')

      expect(data).to include(
        email: contact.email,
        first_name: contact.first_name,
        last_name: contact.last_name,
        company: contact.company,
        Account_Name: contact.company,
        Status__c: contact.status
      )
    end

    it 'sets correct lifecyclestage for inactive contacts in hubspot' do
      inactive_contact = create(:contact, :inactive)
      data = worker.send(:transform_for_crm, inactive_contact, 'hubspot')

      expect(data[:lifecyclestage]).to eq('other')
    end
  end
end
