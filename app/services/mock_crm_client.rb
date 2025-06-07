class MockCrmClient
  def initialize(provider_name)
    @provider = provider_name
    # Read failure rate from environment variable, with fallback to default
    @failure_rate = ENV["#{provider_name.upcase}_FAILURE_RATE"]&.to_f || 0.05
  end

  def create_contact(data)
    simulate_api_call('CREATE', data)
  end

  def update_contact(id, data)
    simulate_api_call('UPDATE', data.merge(id: id))
  end

  def delete_contact(id)
    simulate_api_call('DELETE', { id: id })
  end

  private

    def simulate_api_call(operation, data)
      # Simulate random failures first, before latency
      if rand < @failure_rate
        raise StandardError, "#{@provider} API error: #{[ 'Rate limit exceeded', 'Service unavailable', 'Timeout' ].sample}"
      end

      # Simulate network latency only if no failure
      sleep(rand(0.1..0.3))

      # Return mock response
      {
        success: true,
        id: data[:id] || SecureRandom.hex(8),
        operation: operation,
        provider: @provider,
        timestamp: Time.now
      }
    end
end
