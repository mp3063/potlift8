class CreatePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :prices do |t|
      t.references :product, null: false, foreign_key: true
      t.references :customer_group, null: true, foreign_key: true
      t.decimal :value, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: 'EUR'
      t.string :price_type, null: false, default: 'base'
      t.datetime :valid_from
      t.datetime :valid_to

      t.timestamps
    end

    # Indexes for efficient queries
    add_index :prices, [ :product_id, :price_type ]
    add_index :prices, [ :product_id, :customer_group_id ], unique: true, where: 'customer_group_id IS NOT NULL'
    add_index :prices, [ :valid_from, :valid_to ]
  end
end
