require 'rails_helper'

RSpec.describe MockCrmClient do
  let(:client) { MockCrmClient.new('salesforce') }

  describe '#create_contact' do
    it 'returns success response with generated ID' do
      response = client.create_contact({ email: 'test@example.com' })
      expect(response[:success]).to be true
      expect(response[:id]).to be_present
      expect(response[:operation]).to eq('CREATE')
      expect(response[:provider]).to eq('salesforce')
      expect(response[:timestamp]).to be_present
    end

    it 'simulates API latency' do
      # Stub rand to always return 1 (above failure rate of 0.05) to avoid random failures
      allow_any_instance_of(Object).to receive(:rand).and_return(1, 0.2) # 1 for failure check, 0.2 for sleep
      
      start_time = Time.now
      client.create_contact({ email: 'test@example.com' })
      end_time = Time.now
      expect(end_time - start_time).to be >= 0.1
    end
  end

  describe '#update_contact' do
    it 'returns success response with provided ID' do
      response = client.update_contact('123', { email: 'updated@example.com' })
      expect(response[:success]).to be true
      expect(response[:id]).to eq('123')
      expect(response[:operation]).to eq('UPDATE')
    end
  end

  describe '#delete_contact' do
    it 'returns success response' do
      response = client.delete_contact('123')
      expect(response[:success]).to be true
      expect(response[:id]).to eq('123')
      expect(response[:operation]).to eq('DELETE')
    end
  end

  context 'with high failure rate' do
    before do
      allow(ENV).to receive(:[]).with('SALESFORCE_FAILURE_RATE').and_return('1.0')
    end

    let(:client) { MockCrmClient.new('salesforce') }

    it 'simulates API failures' do
      expect {
        client.create_contact({ email: 'test@example.com' })
      }.to raise_error(StandardError, /salesforce API error/)
    end
  end

  context 'with zero failure rate' do
    before do
      allow(ENV).to receive(:[]).with('SALESFORCE_FAILURE_RATE').and_return('0.0')
    end

    let(:client) { MockCrmClient.new('salesforce') }

    it 'never fails' do
      # Run multiple times to ensure no failures
      10.times do
        expect {
          client.create_contact({ email: 'test@example.com' })
        }.not_to raise_error
      end
    end
  end
end