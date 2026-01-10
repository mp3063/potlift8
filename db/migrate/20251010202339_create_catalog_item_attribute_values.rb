class CreateCatalogItemAttributeValues < ActiveRecord::Migration[8.0]
  def change
    create_table :catalog_item_attribute_values do |t|
      t.references :catalog_item, null: false, foreign_key: true, index: false
      t.references :product_attribute, null: false, foreign_key: true, index: false
      t.text :value
      t.jsonb :info, default: {}
      t.boolean :ready, default: true
      t.timestamps

      t.index [ :catalog_item_id, :product_attribute_id ], unique: true, name: 'ciav_index'
    end
  end
end
