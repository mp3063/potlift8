class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :company, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.jsonb :info, default: {}, null: false

      t.timestamps
    end

    add_index :products, [ :company_id, :sku ], unique: true
  end
end
