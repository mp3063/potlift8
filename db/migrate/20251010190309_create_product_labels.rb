class CreateProductLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :product_labels do |t|
      # Foreign keys to products and labels
      t.references :product, null: false, foreign_key: true, index: true
      t.references :label, null: false, foreign_key: true, index: true

      t.timestamps
    end

    # Unique constraint to prevent duplicate product-label associations
    add_index :product_labels, [:product_id, :label_id], unique: true
  end
end
