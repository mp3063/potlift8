class CreateProductAttributes < ActiveRecord::Migration[8.0]
  def change
    create_table :product_attributes do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :pa_type, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :description
      t.boolean :mandatory, default: false, null: false
      t.string :default_value
      t.jsonb :info, default: {}, null: false
      t.integer :view_format, default: 0, null: false
      t.integer :attribute_position
      t.integer :product_attribute_scope, default: 0, null: false
      t.boolean :localizable, default: false, null: false
      t.boolean :subproduct_mandatory, default: false, null: false
      t.jsonb :rules, default: {}, null: false
      t.boolean :has_rules, default: false, null: false

      t.timestamps
    end

    add_index :product_attributes, [ :company_id, :code ], unique: true
  end
end
