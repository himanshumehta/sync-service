class SyncWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: 'sync_high'

  def initialize
    @rate_limiter = RateLimiter.new
    @rate_limiter.set_limit('salesforce', 100)
    @rate_limiter.set_limit('hubspot', 50)

    @circuit_breaker = CircuitBreaker.new

    @crm_clients = {
      'salesforce' => MockCrmClient.new('salesforce'),
      'hubspot' => MockCrmClient.new('hubspot')
    }
  end

  def perform(contact_id, operation, crm_provider)
    contact = Contact.find(contact_id)

    # Check rate limit
    unless @rate_limiter.allow?(crm_provider)
      # Reschedule for later
      self.class.perform_in(30.seconds, contact_id, operation, crm_provider)
      return
    end

    # Execute with circuit breaker protection
    @circuit_breaker.call(crm_provider) do
      sync_to_crm(contact, operation, crm_provider)
    end
  rescue CircuitBreaker::CircuitBreakerOpenError => e
    # Reschedule when circuit is open
    self.class.perform_in(60.seconds, contact_id, operation, crm_provider)
    Rails.logger.warn "Circuit breaker open for #{crm_provider}: #{e.message}"
  rescue => e
    Rails.logger.error "Sync failed for contact #{contact_id} to #{crm_provider}: #{e.message}"
    raise e # Let Sidekiq handle retries
  end

  private

    def sync_to_crm(contact, operation, crm_provider)
      client = @crm_clients[crm_provider]
      raise "Unknown CRM: #{crm_provider}" unless client

      contact_data = transform_for_crm(contact, crm_provider)

      case operation
      when 'CREATE'
        client.create_contact(contact_data)
      when 'UPDATE'
        client.update_contact(contact.id, contact_data)
      when 'DELETE'
        client.delete_contact(contact.id)
      end

      # Log successful sync
      Rails.logger.info "Successfully synced contact #{contact.id} to #{crm_provider}"
    end

    def transform_for_crm(contact, crm_provider)
      # Mock transformation
      base_data = {
        email: contact.email,
        first_name: contact.first_name,
        last_name: contact.last_name,
        company: contact.company
      }

      case crm_provider
      when 'salesforce'
        base_data.merge({
          Account_Name: contact.company, # Salesforce specific field
          Status__c: contact.status
        })
      when 'hubspot'
        base_data.merge({
          lifecyclestage: contact.status == 'active' ? 'customer' : 'other' # HubSpot specific
        })
      else
        base_data
      end
    end
end
