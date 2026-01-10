class AddFieldsToCompanyStates < ActiveRecord::Migration[8.0]
  def change
    add_column :company_states, :company_id, :bigint, null: false
    add_column :company_states, :code, :string, null: false
    add_column :company_states, :state, :string

    add_foreign_key :company_states, :companies
    add_index :company_states, [ :company_id, :code ], unique: true
  end
end
