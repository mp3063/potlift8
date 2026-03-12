class AddSystemAndShopifyMetafieldToProductAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :product_attributes, :system, :boolean, default: false, null: false
    add_column :product_attributes, :shopify_metafield_namespace, :string
    add_column :product_attributes, :shopify_metafield_key, :string
    add_column :product_attributes, :shopify_metafield_type, :string

    add_index :product_attributes, [:company_id, :system]
  end
end
