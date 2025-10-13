class CreateCompanyMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :company_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :role, null: false, default: 'member'

      t.timestamps
    end
    add_index :company_memberships, [:user_id, :company_id], unique: true
  end
end
