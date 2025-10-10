class CreateInventories < ActiveRecord::Migration[8.0]
  def change
    create_table :inventories do |t|
      t.references :product, null: false, foreign_key: true
      t.references :storage, null: false, foreign_key: true
      t.integer :value, default: 0, null: false
      t.jsonb :info, default: {}, null: false
      t.boolean :default, default: false
      t.date :eta

      t.timestamps
    end

    add_index :inventories, [:product_id, :storage_id], unique: true, name: 'inventories_product_storage_unique_index'
  end
end
