class SyncEvaluator
  def self.process(contact, operation)
    SyncRulesEngine.applicable_crms(contact, operation).each do |crm|
      priority = operation_priority(operation)
      SyncWorker.set(queue: "sync_#{priority}").perform_async(
        contact.id, operation, crm
      )
    end
  end

  private

    def self.operation_priority(operation)
      case operation
      when 'CREATE' then 'critical'
      when 'UPDATE' then 'high'
      when 'DELETE' then 'normal'
      else 'low'
      end
    end
end
