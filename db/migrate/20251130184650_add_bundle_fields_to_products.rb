class AddBundleFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_reference :products, :parent_bundle, foreign_key: { to_table: :products }, null: true, index: true
    add_column :products, :bundle_variant, :boolean, default: false, null: false

    add_index :products, :bundle_variant
  end
end
