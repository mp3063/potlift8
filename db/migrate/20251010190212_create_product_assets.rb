class CreateProductAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :product_assets do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name
      t.integer :product_asset_type, null: false
      t.integer :asset_priority
      t.integer :asset_visibility
      t.text :asset_description
      t.jsonb :info, default: {}

      t.timestamps
    end

    add_index :product_assets, [ :product_id, :asset_priority ], name: 'index_product_assets_on_product_id_and_priority'
  end
end
