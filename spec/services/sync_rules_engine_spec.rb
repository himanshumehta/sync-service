require 'rails_helper'

RSpec.describe SyncRulesEngine do
  describe '.applicable_crms' do
    context 'for CREATE operation' do
      it 'returns salesforce for any contact (always)' do
        contact = create(:contact, company: nil, status: 'inactive')
        result = described_class.applicable_crms(contact, 'CREATE')

        expect(result).to include('salesforce')
      end

      it 'returns hubspot only when contact has company' do
        contact_with_company = create(:contact, company: 'Acme Corp')
        contact_without_company = create(:contact, company: nil)

        result_with_company = described_class.applicable_crms(contact_with_company, 'CREATE')
        result_without_company = described_class.applicable_crms(contact_without_company, 'CREATE')

        expect(result_with_company).to include('hubspot')
        expect(result_without_company).not_to include('hubspot')
      end

      it 'returns both CRMs when contact has company' do
        contact = create(:contact, company: 'Acme Corp')
        result = described_class.applicable_crms(contact, 'CREATE')

        expect(result).to contain_exactly('salesforce', 'hubspot')
      end
    end

    context 'for UPDATE operation' do
      it 'returns salesforce only for active contacts' do
        active_contact = create(:contact, status: 'active')
        inactive_contact = create(:contact, status: 'inactive')

        active_result = described_class.applicable_crms(active_contact, 'UPDATE')
        inactive_result = described_class.applicable_crms(inactive_contact, 'UPDATE')

        expect(active_result).to include('salesforce')
        expect(inactive_result).not_to include('salesforce')
      end

      it 'returns hubspot for any contact (always)' do
        contact = create(:contact, status: 'inactive', company: nil)
        result = described_class.applicable_crms(contact, 'UPDATE')

        expect(result).to include('hubspot')
      end

      it 'returns both CRMs for active contacts' do
        contact = create(:contact, status: 'active')
        result = described_class.applicable_crms(contact, 'UPDATE')

        expect(result).to contain_exactly('salesforce', 'hubspot')
      end
    end

    context 'for DELETE operation' do
      it 'never returns salesforce' do
        contact = create(:contact, status: 'deleted')
        result = described_class.applicable_crms(contact, 'DELETE')

        expect(result).not_to include('salesforce')
      end

      it 'returns hubspot only for deleted contacts' do
        deleted_contact = create(:contact, status: 'deleted')
        active_contact = create(:contact, status: 'active')

        deleted_result = described_class.applicable_crms(deleted_contact, 'DELETE')
        active_result = described_class.applicable_crms(active_contact, 'DELETE')

        expect(deleted_result).to include('hubspot')
        expect(active_result).not_to include('hubspot')
      end
    end

    context 'for unknown operation' do
      it 'returns empty array' do
        contact = create(:contact)
        result = described_class.applicable_crms(contact, 'UNKNOWN')

        expect(result).to be_empty
      end
    end
  end

  describe '.should_sync?' do
    let(:contact) { create(:contact, status: 'active', company: 'Acme Corp') }

    context 'with always condition' do
      it 'returns true' do
        expect(described_class.should_sync?(contact, 'CREATE', 'salesforce')).to be true
      end
    end

    context 'with never condition' do
      it 'returns false' do
        expect(described_class.should_sync?(contact, 'DELETE', 'salesforce')).to be false
      end
    end

    context 'with has_company condition' do
      it 'returns true when contact has company' do
        contact_with_company = create(:contact, company: 'Acme Corp')
        expect(described_class.should_sync?(contact_with_company, 'CREATE', 'hubspot')).to be true
      end
    end

    context 'with deleted_status condition' do
      it 'returns true for deleted contacts' do
        deleted_contact = create(:contact, status: 'deleted')
        expect(described_class.should_sync?(deleted_contact, 'DELETE', 'hubspot')).to be true
      end

      it 'returns false for non-deleted contacts' do
        active_contact = create(:contact, status: 'active')
        expect(described_class.should_sync?(active_contact, 'DELETE', 'hubspot')).to be false
      end
    end

    context 'with unknown condition' do
      before do
        # Temporarily modify RULES to test unknown condition
        stub_const('SyncRulesEngine::RULES', {
          'test_crm' => { 'TEST' => 'unknown_condition' }
        })
      end

      it 'returns false' do
        expect(described_class.should_sync?(contact, 'TEST', 'test_crm')).to be false
      end
    end

    context 'with non-existent CRM or operation' do
      it 'returns false for non-existent CRM' do
        expect(described_class.should_sync?(contact, 'CREATE', 'unknown_crm')).to be false
      end
    end
  end
end
