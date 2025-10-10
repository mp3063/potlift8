class AddFieldsToLabels < ActiveRecord::Migration[8.0]
  def change
    # Company association (multi-tenancy)
    add_reference :labels, :company, null: false, foreign_key: true, index: true

    # Label identification
    add_column :labels, :label_type, :string, null: false
    add_column :labels, :code, :string, null: false
    add_column :labels, :full_code, :string, null: false
    add_column :labels, :name, :string, null: false
    add_column :labels, :full_name, :string, null: false
    add_column :labels, :description, :string

    # Metadata storage
    add_column :labels, :info, :jsonb, default: {}, null: false

    # Self-referential parent-child relationship
    add_reference :labels, :parent_label, foreign_key: { to_table: :labels }, index: true

    # Ordering
    add_column :labels, :label_positions, :integer

    # Product association restrictions
    add_column :labels, :product_default_restriction, :integer, default: 1

    # Unique constraint on company_id + full_code
    add_index :labels, [:company_id, :full_code], unique: true
  end
end
