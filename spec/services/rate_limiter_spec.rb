require 'rails_helper'

RSpec.describe RateLimiter do
  let(:redis) { Redis.new }
  let(:rate_limiter) { described_class.new(redis, default_limit: 5, window_size: 60) }
  let(:test_key) { 'test_service' }

  before do
    redis.flushdb
  end

  after do
    redis.flushdb
  end

  describe '#initialize' do
    it 'sets default configuration' do
      limiter = described_class.new(redis)
      expect(limiter.instance_variable_get(:@default_limit)).to eq(60)
      expect(limiter.instance_variable_get(:@window_size)).to eq(60)
    end

    it 'accepts custom configuration' do
      limiter = described_class.new(redis, default_limit: 100, window_size: 120)
      expect(limiter.instance_variable_get(:@default_limit)).to eq(100)
      expect(limiter.instance_variable_get(:@window_size)).to eq(120)
    end
  end

  describe '#set_limit' do
    it 'sets custom limit for a key' do
      rate_limiter.set_limit(test_key, 10)
      limits = rate_limiter.instance_variable_get(:@limits)
      expect(limits[test_key]).to eq(10)
    end
  end

  describe '#allow?' do
    context 'when under the limit' do
      it 'allows requests' do
        4.times do
          expect(rate_limiter.allow?(test_key)).to be true
        end
      end
    end

    context 'when at the limit' do
      it 'allows the last request within limit' do
        5.times do
          expect(rate_limiter.allow?(test_key)).to be true
        end
      end
    end

    context 'when over the limit' do
      it 'denies additional requests' do
        5.times { rate_limiter.allow?(test_key) }
        expect(rate_limiter.allow?(test_key)).to be false
      end
    end

    context 'with custom limit' do
      before do
        rate_limiter.set_limit(test_key, 2)
      end

      it 'uses custom limit instead of default' do
        2.times do
          expect(rate_limiter.allow?(test_key)).to be true
        end
        expect(rate_limiter.allow?(test_key)).to be false
      end
    end

    context 'with sliding window behavior' do
      it 'allows requests after window expires' do
        # Fill up the limit
        5.times { rate_limiter.allow?(test_key) }
        expect(rate_limiter.allow?(test_key)).to be false

        # Mock time passing beyond window
        allow(Time).to receive(:now).and_return(Time.now + 61)
        expect(rate_limiter.allow?(test_key)).to be true
      end
    end
  end

  describe '#current_usage' do
    it 'returns zero for unused key' do
      expect(rate_limiter.current_usage(test_key)).to eq(0)
    end

    it 'returns correct count after requests' do
      3.times { rate_limiter.allow?(test_key) }
      expect(rate_limiter.current_usage(test_key)).to eq(3)
    end

    it 'excludes expired entries from count' do
      3.times { rate_limiter.allow?(test_key) }

      # Mock time passing beyond window
      allow(Time).to receive(:now).and_return(Time.now + 61)
      expect(rate_limiter.current_usage(test_key)).to eq(0)
    end
  end

  describe '#reset' do
    it 'clears all entries for a key' do
      3.times { rate_limiter.allow?(test_key) }
      expect(rate_limiter.current_usage(test_key)).to eq(3)

      rate_limiter.reset(test_key)
      expect(rate_limiter.current_usage(test_key)).to eq(0)
    end
  end
end
