require 'rails_helper'

RSpec.describe CircuitBreaker do
  let(:redis) { Redis.new }
  let(:circuit_breaker) { described_class.new(redis, failure_threshold: 3, timeout: 30) }
  let(:test_key) { 'test_service' }
  let(:success_block) { -> { 'success' } }
  let(:failure_block) { -> { raise StandardError, 'failure' } }

  before do
    redis.flushdb
  end

  after do
    redis.flushdb
  end

  describe '#initialize' do
    it 'sets default configuration' do
      breaker = described_class.new(redis)
      expect(breaker.instance_variable_get(:@failure_threshold)).to eq(5)
      expect(breaker.instance_variable_get(:@timeout)).to eq(30)
    end

    it 'accepts custom configuration' do
      breaker = described_class.new(redis, failure_threshold: 10, timeout: 60)
      expect(breaker.instance_variable_get(:@failure_threshold)).to eq(10)
      expect(breaker.instance_variable_get(:@timeout)).to eq(60)
    end
  end

  describe '#call' do
    context 'when circuit is closed' do
      it 'executes the block and returns result' do
        result = circuit_breaker.call(test_key, &success_block)
        expect(result).to eq('success')
      end

      it 'allows exceptions to propagate' do
        expect do
          circuit_breaker.call(test_key, &failure_block)
        end.to raise_error(StandardError, 'failure')
      end

      it 'increments failure count on exception' do
        begin
          circuit_breaker.call(test_key, &failure_block)
        rescue StandardError
          # Expected
        end

        expect(circuit_breaker.current_failure_count(test_key)).to eq(1)
      end

      it 'resets failure count on success after failures' do
        # Generate some failures
        2.times do
          begin
            circuit_breaker.call(test_key, &failure_block)
          rescue StandardError
            # Expected
          end
        end

        expect(circuit_breaker.current_failure_count(test_key)).to eq(2)

        # Success should reset count
        circuit_breaker.call(test_key, &success_block)
        expect(circuit_breaker.current_failure_count(test_key)).to eq(0)
      end
    end

    context 'when reaching failure threshold' do
      it 'opens the circuit' do
        # Generate failures to reach threshold
        3.times do
          begin
            circuit_breaker.call(test_key, &failure_block)
          rescue StandardError
            # Expected
          end
        end

        expect(circuit_breaker.current_state(test_key)).to eq(CircuitBreaker::STATE_OPEN)
      end
    end

    context 'when circuit is open' do
      before do
        # Force circuit to open state
        3.times do
          begin
            circuit_breaker.call(test_key, &failure_block)
          rescue StandardError
            # Expected
          end
        end
      end

      it 'raises CircuitBreakerOpenError immediately' do
        expect do
          circuit_breaker.call(test_key, &success_block)
        end.to raise_error(CircuitBreaker::CircuitBreakerOpenError)
      end

      it 'transitions to half-open after timeout' do
        # Mock time passing beyond timeout
        allow(Time).to receive(:now).and_return(Time.now + 31)

        expect do
          circuit_breaker.call(test_key, &success_block)
        end.not_to raise_error
      end
    end

    context 'when circuit is half-open' do
      before do
        # Force circuit to open state
        3.times do
          begin
            circuit_breaker.call(test_key, &failure_block)
          rescue StandardError
            # Expected
          end
        end

        # Move to half-open by advancing time
        allow(Time).to receive(:now).and_return(Time.now + 31)
      end

      it 'closes circuit on successful call' do
        circuit_breaker.call(test_key, &success_block)
        expect(circuit_breaker.current_state(test_key)).to eq(CircuitBreaker::STATE_CLOSED)
      end

      it 'reopens circuit on failed call' do
        expect do
          circuit_breaker.call(test_key, &failure_block)
        end.to raise_error(StandardError)

        expect(circuit_breaker.current_state(test_key)).to eq(CircuitBreaker::STATE_OPEN)
      end
    end
  end

  describe '#current_state' do
    it 'returns closed by default' do
      expect(circuit_breaker.current_state(test_key)).to eq(CircuitBreaker::STATE_CLOSED)
    end
  end

  describe '#current_failure_count' do
    it 'returns zero by default' do
      expect(circuit_breaker.current_failure_count(test_key)).to eq(0)
    end

    it 'returns correct count after failures' do
      2.times do
        begin
          circuit_breaker.call(test_key, &failure_block)
        rescue StandardError
          # Expected
        end
      end

      expect(circuit_breaker.current_failure_count(test_key)).to eq(2)
    end
  end

  describe '#reset' do
    before do
      # Generate some failures and open the circuit
      3.times do
        begin
          circuit_breaker.call(test_key, &failure_block)
        rescue StandardError
          # Expected
        end
      end
    end

    it 'resets circuit to closed state' do
      circuit_breaker.reset(test_key)
      expect(circuit_breaker.current_state(test_key)).to eq(CircuitBreaker::STATE_CLOSED)
      expect(circuit_breaker.current_failure_count(test_key)).to eq(0)
    end

    it 'allows normal operation after reset' do
      circuit_breaker.reset(test_key)
      result = circuit_breaker.call(test_key, &success_block)
      expect(result).to eq('success')
    end
  end

  describe 'integration scenarios' do
    it 'handles multiple keys independently' do
      key1 = 'service1'
      key2 = 'service2'

      # Fail key1 enough to open circuit
      3.times do
        begin
          circuit_breaker.call(key1, &failure_block)
        rescue StandardError
          # Expected
        end
      end

      # key1 should be open
      expect(circuit_breaker.current_state(key1)).to eq(CircuitBreaker::STATE_OPEN)
      # key2 should still be closed
      expect(circuit_breaker.current_state(key2)).to eq(CircuitBreaker::STATE_CLOSED)

      # key2 should still work
      result = circuit_breaker.call(key2, &success_block)
      expect(result).to eq('success')
    end
  end
end
