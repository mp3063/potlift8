class AddAttributeGroupIdToProductAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :product_attributes, :attribute_group_id, :bigint, null: true
    add_index :product_attributes, :attribute_group_id
    add_foreign_key :product_attributes, :attribute_groups
  end
end
