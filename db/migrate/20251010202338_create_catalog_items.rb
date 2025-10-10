class CreateCatalogItems < ActiveRecord::Migration[8.0]
  def change
    create_table :catalog_items do |t|
      t.references :catalog, null: false, foreign_key: true, index: false
      t.references :product, null: false, foreign_key: true, index: false
      t.integer :priority
      t.integer :catalog_item_state, null: false, default: 0
      t.jsonb :info, default: {}
      t.timestamps

      t.index [:catalog_id, :product_id], unique: true
      t.index :catalog_item_state
      t.index :priority
    end
  end
end
