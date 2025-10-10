class CreateCompanyStates < ActiveRecord::Migration[8.0]
  def change
    create_table :company_states do |t|
      t.bigint :company_id, null: false
      t.string :code, null: false
      t.string :state

      t.timestamps
    end

    add_foreign_key :company_states, :companies
    add_index :company_states, [:company_id, :code], unique: true
  end
end
