class CreateLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :labels do |t|
      # Company association (multi-tenancy)
      t.references :company, null: false, foreign_key: true, index: true

      # Label identification
      t.string :label_type, null: false
      t.string :code, null: false
      t.string :full_code, null: false
      t.string :name, null: false
      t.string :full_name, null: false
      t.string :description

      # Metadata storage
      t.jsonb :info, default: {}, null: false

      # Self-referential parent-child relationship
      t.references :parent_label, foreign_key: { to_table: :labels }, index: true

      # Ordering
      t.integer :label_positions

      # Product association restrictions
      t.integer :product_default_restriction, default: 1

      t.timestamps
    end

    # Unique constraint on company_id + full_code
    add_index :labels, [ :company_id, :full_code ], unique: true
  end
end
