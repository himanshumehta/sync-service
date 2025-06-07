class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :company
      t.integer :status

      t.timestamps
    end
  end
end
