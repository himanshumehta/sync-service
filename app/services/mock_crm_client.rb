class MockCrmClient
  def initialize(provider_name)
    @provider = provider_name
    @failure_rate = 0.05
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
      # Simulate network latency
      sleep(rand(0.1..0.3))

      # Simulate random failures
      if rand < @failure_rate
        raise StandardError, "#{@provider} API error: #{[ 'Rate limit exceeded', 'Service unavailable', 'Timeout' ].sample}"
      end

      # Return mock response
      {
        success: true,
        id: data[:id] || SecureRandom.hex(8),
        operation: operation,
        provider: @provider,
        timestamp: Time.now.iso8601
      }
    end
end
