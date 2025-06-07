require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe 'factory' do
    it 'creates a valid contact' do
      contact = build(:contact)
      expect(contact).to be_valid
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: 0, inactive: 1, deleted: 2) }
  end
end
