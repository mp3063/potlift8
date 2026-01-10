class CreateRelatedProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :related_products do |t|
      t.references :product, null: false, foreign_key: { on_delete: :cascade }
      t.references :related_to, null: false, foreign_key: { to_table: :products, on_delete: :cascade }
      t.integer :relation_type, null: false, default: 0, comment: 'Enum: cross_sell, upsell, alternative, accessory, related, similar'
      t.integer :position, null: false, default: 1, comment: 'Display order within relation type'
      t.jsonb :info, default: {}, null: false, comment: 'Metadata: discount, notes, conditions, etc.'
      t.timestamps

      # Performance: Ordered retrieval of related products by type
      t.index [ :product_id, :relation_type, :position ],
              name: 'index_related_products_on_product_type_position',
              comment: 'Optimizes ordered related product retrieval by type'

      # Performance: Reverse lookups - find products that reference this product
      t.index [ :related_to_id, :relation_type ],
              name: 'index_related_products_on_related_to_and_type',
              comment: 'Optimizes reverse lookups (which products reference this one)'

      # Uniqueness: Prevent duplicate relationships
      t.index [ :product_id, :related_to_id, :relation_type ],
              unique: true,
              name: 'index_related_products_unique_relation',
              comment: 'Ensures unique product relationships per type'

      # Performance: Full relation type queries
      t.index :relation_type,
              name: 'index_related_products_on_relation_type',
              comment: 'Optimizes queries filtering by relation type'

      # JSONB indexing for common info queries
      t.index :info,
              using: :gin,
              name: 'index_related_products_on_info',
              comment: 'Supports JSONB queries on relationship metadata'
    end

    # Constraint: Prevent self-reference
    add_check_constraint :related_products,
                         'product_id != related_to_id',
                         name: 'related_products_no_self_reference',
                         comment: 'Prevents products from being related to themselves'

    # Constraint: Validate position range
    add_check_constraint :related_products,
                         'position > 0 AND position < 1000',
                         name: 'related_products_position_range',
                         comment: 'Ensures position is between 1 and 999'

    # Constraint: Validate relation_type enum values (0-5)
    add_check_constraint :related_products,
                         'relation_type >= 0 AND relation_type <= 5',
                         name: 'related_products_relation_type_range',
                         comment: 'Ensures relation_type matches enum values (0-5)'

    # Add comments for documentation
    reversible do |dir|
      dir.up do
        execute <<-SQL
          COMMENT ON TABLE related_products IS 'Product relationships for cross-sell, upsell, alternatives, accessories, etc.';
          COMMENT ON COLUMN related_products.product_id IS 'Source product';
          COMMENT ON COLUMN related_products.related_to_id IS 'Target product (related/recommended)';
          COMMENT ON COLUMN related_products.relation_type IS 'Enum: 0=cross_sell, 1=upsell, 2=alternative, 3=accessory, 4=related, 5=similar';
          COMMENT ON COLUMN related_products.position IS 'Display order within relation type';
          COMMENT ON COLUMN related_products.info IS 'JSONB: discount_percentage, display_condition, promotion_text, visibility_rules';
        SQL
      end
    end
  end
end
