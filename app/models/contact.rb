class Contact < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  enum :status, { active: 0, inactive: 1, deleted: 2 }
  after_create :trigger_sync_create
  after_update :trigger_sync_update
  after_destroy :trigger_sync_delete

  private

    def trigger_sync_create
      SyncEvaluator.process(self, 'CREATE')
    end

    def trigger_sync_update
      SyncEvaluator.process(self, 'UPDATE')
    end

    def trigger_sync_delete
      SyncEvaluator.process(self, 'DELETE')
    end
end
