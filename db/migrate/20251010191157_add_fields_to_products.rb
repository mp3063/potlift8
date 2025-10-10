class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    # Add foreign keys
    add_reference :products, :company, null: false, foreign_key: true, index: true
    add_reference :products, :sync_lock, null: true, foreign_key: true, index: true

    # Add product identification fields
    add_column :products, :sku, :string, null: false
    add_column :products, :name, :string, null: false
    add_column :products, :ean, :string

    # Add product type and configuration fields
    add_column :products, :product_type, :integer, null: false
    add_column :products, :configuration_type, :integer

    # Add JSONB fields for flexible data storage
    add_column :products, :structure, :jsonb, default: {}, null: false
    add_column :products, :info, :jsonb, default: {}, null: false
    add_column :products, :cache, :jsonb, default: {}, null: false

    # Add status field
    add_column :products, :product_status, :integer

    # Add unique constraint on company_id + sku
    add_index :products, [:company_id, :sku], unique: true, name: 'products_company_sku_unique_index'

    # Add indexes for frequently queried fields
    add_index :products, :product_status
    add_index :products, :product_type
  end
end
