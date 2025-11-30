class UpdateProductsSkuIndexToExcludeDeleted < ActiveRecord::Migration[8.0]
  def up
    # Remove the old unique index
    remove_index :products, name: 'products_company_sku_unique_index'

    # Add a new partial unique index that excludes deleted products
    add_index :products,
              [:company_id, :sku],
              unique: true,
              name: 'products_company_sku_unique_index',
              where: "product_status != 999" # 999 is the enum value for :deleted
  end

  def down
    # Remove the partial index
    remove_index :products, name: 'products_company_sku_unique_index'

    # Restore the old full unique index
    add_index :products,
              [:company_id, :sku],
              unique: true,
              name: 'products_company_sku_unique_index'
  end
end
