class Contact < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  enum status: { active: 0, inactive: 1, deleted: 2 }
end
