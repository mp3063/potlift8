class CreateProductConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :product_configurations do |t|
      t.bigint :superproduct_id, null: false
      t.bigint :subproduct_id, null: false
      t.integer :configuration_position
      t.jsonb :info, default: {}, null: false

      t.timestamps
    end

    # Add foreign keys
    add_foreign_key :product_configurations, :products, column: :superproduct_id
    add_foreign_key :product_configurations, :products, column: :subproduct_id

    # Add indexes
    add_index :product_configurations, :superproduct_id
    add_index :product_configurations, :subproduct_id
    add_index :product_configurations, [:superproduct_id, :subproduct_id],
              unique: true,
              name: 'index_product_configs_on_super_and_sub'
  end
end
