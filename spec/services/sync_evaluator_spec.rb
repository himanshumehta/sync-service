require 'rails_helper'

RSpec.describe SyncEvaluator do
  let(:contact) { create(:contact, status: 'active', company: 'Acme Corp') }

  before do
    # Stub SyncWorker to capture job calls
    allow(SyncWorker).to receive(:set).and_return(SyncWorker)
    allow(SyncWorker).to receive(:perform_async)
  end

  describe '.process' do
    context 'when multiple CRMs are applicable' do
      before do
        # Stub rules engine to return both CRMs
        allow(SyncRulesEngine).to receive(:applicable_crms)
          .with(contact, 'CREATE')
          .and_return([ 'salesforce', 'hubspot' ])
      end

      it 'queues jobs for all applicable CRMs' do
        SyncEvaluator.process(contact, 'CREATE')

        expect(SyncWorker).to have_received(:set).with(queue: 'sync_critical').twice
        expect(SyncWorker).to have_received(:perform_async)
          .with(contact.id, 'CREATE', 'salesforce')
        expect(SyncWorker).to have_received(:perform_async)
          .with(contact.id, 'CREATE', 'hubspot')
      end
    end

    context 'when no CRMs are applicable' do
      before do
        allow(SyncRulesEngine).to receive(:applicable_crms)
          .with(contact, 'DELETE')
          .and_return([])
      end

      it 'does not queue any jobs' do
        SyncEvaluator.process(contact, 'DELETE')

        expect(SyncWorker).not_to have_received(:set)
        expect(SyncWorker).not_to have_received(:perform_async)
      end
    end

    context 'when only one CRM is applicable' do
      before do
        allow(SyncRulesEngine).to receive(:applicable_crms)
          .with(contact, 'UPDATE')
          .and_return([ 'salesforce' ])
      end

      it 'queues job for single CRM' do
        SyncEvaluator.process(contact, 'UPDATE')

        expect(SyncWorker).to have_received(:set).with(queue: 'sync_high').once
        expect(SyncWorker).to have_received(:perform_async)
          .with(contact.id, 'UPDATE', 'salesforce')
      end
    end
  end

  describe '.operation_priority' do
    it 'returns correct priorities for operations' do
      expect(described_class.send(:operation_priority, 'CREATE')).to eq('critical')
      expect(described_class.send(:operation_priority, 'UPDATE')).to eq('high')
      expect(described_class.send(:operation_priority, 'DELETE')).to eq('normal')
      expect(described_class.send(:operation_priority, 'READ')).to eq('low')
      expect(described_class.send(:operation_priority, 'UNKNOWN')).to eq('low')
    end
  end
end
