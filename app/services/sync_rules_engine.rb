class SyncRulesEngine
  RULES = {
    'salesforce' => {
      'CREATE' => 'always',
      'UPDATE' => 'active_only',
      'DELETE' => 'never'
    },
    'hubspot' => {
      'CREATE' => 'has_company',
      'UPDATE' => 'always',
      'DELETE' => 'deleted_status'
    }
  }.freeze

  def self.applicable_crms(contact, operation)
    RULES.keys.select do |crm|
      should_sync?(contact, operation, crm)
    end
  end

  def self.should_sync?(contact, operation, crm)
    condition = RULES.dig(crm, operation)
    return false unless condition

    case condition
    when 'always' then true
    when 'never' then false
    when 'active_only' then contact.status == 'active'
    when 'has_company' then contact.company.present?
    when 'deleted_status' then contact.status == 'deleted'
    else false
    end
  end
end
