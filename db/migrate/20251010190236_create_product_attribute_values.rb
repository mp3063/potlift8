class CreateProductAttributeValues < ActiveRecord::Migration[8.0]
  def change
    create_table :product_attribute_values do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_attribute, null: false, foreign_key: true
      t.text :value
      t.jsonb :info, default: {}, null: false
      t.boolean :ready, default: false, null: false

      t.timestamps
    end

    add_index :product_attribute_values, [ :product_id, :product_attribute_id ], unique: true, name: 'pavs_index'
  end
end
