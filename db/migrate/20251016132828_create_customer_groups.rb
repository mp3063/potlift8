class CreateCustomerGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_groups do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0
      t.jsonb :info, default: {}

      t.timestamps
    end

    add_index :customer_groups, [ :company_id, :code ], unique: true
    add_index :customer_groups, [ :company_id, :name ]
  end
end
