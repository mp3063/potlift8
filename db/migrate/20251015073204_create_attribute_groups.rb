class CreateAttributeGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :attribute_groups do |t|
      t.bigint :company_id, null: false
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.integer :position
      t.jsonb :info, default: {}, null: false

      t.timestamps
    end

    add_index :attribute_groups, :company_id
    add_index :attribute_groups, [:company_id, :code], unique: true,
      name: "index_attribute_groups_on_company_id_and_code"
    add_foreign_key :attribute_groups, :companies
  end
end
