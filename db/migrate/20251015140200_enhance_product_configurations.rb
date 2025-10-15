class EnhanceProductConfigurations < ActiveRecord::Migration[8.0]
  def up
    # Add quantity column for bundle components (extracted from JSONB for performance)
    add_column :product_configurations, :quantity, :integer, default: 1, null: false,
               comment: 'Quantity for bundle components (1 for variants)'

    # Migrate existing quantity data from info['quantity'] to dedicated column
    execute <<-SQL
      UPDATE product_configurations
      SET quantity = COALESCE((info->>'quantity')::integer, 1)
      WHERE info ? 'quantity';
    SQL

    # Optional: Clean up migrated data from JSONB (uncomment if desired)
    # execute <<-SQL
    #   UPDATE product_configurations
    #   SET info = info - 'quantity'
    #   WHERE info ? 'quantity';
    # SQL

    # Performance: Ordered retrieval of variants/components for a product
    add_index :product_configurations, [:superproduct_id, :configuration_position],
              name: 'index_pc_on_super_and_position',
              comment: 'Optimizes ordered variant/component retrieval for parent product'

    # Performance: Reverse lookup - find parent products containing a specific product
    add_index :product_configurations, [:subproduct_id, :superproduct_id],
              name: 'index_pc_on_sub_and_super',
              comment: 'Optimizes reverse lookup to find parent products'

    # Performance: Bundle quantity queries (e.g., find components with quantity > 1)
    add_index :product_configurations, :quantity,
              where: 'quantity > 1',
              name: 'index_pc_on_quantity',
              comment: 'Optimizes bundle component quantity queries'

    # Add check constraint for quantity validation
    add_check_constraint :product_configurations,
                         'quantity > 0 AND quantity <= 10000',
                         name: 'product_configurations_quantity_range',
                         comment: 'Ensures quantity is between 1 and 10000'

    # Add check constraint for position validation
    add_check_constraint :product_configurations,
                         'configuration_position > 0 AND configuration_position < 10000',
                         name: 'product_configurations_position_range',
                         comment: 'Ensures position is between 1 and 9999'

    # Update table and column comments
    execute <<-SQL
      COMMENT ON TABLE product_configurations IS 'Links products to their variants (configurable) or components (bundle). Single source of truth for all product relationships.';
      COMMENT ON COLUMN product_configurations.quantity IS 'Number of units for bundle components (always 1 for variants)';
      COMMENT ON COLUMN product_configurations.configuration_position IS 'Display order within parent product';
      COMMENT ON COLUMN product_configurations.info IS 'JSONB: Additional metadata (price_modifier, discount, notes, etc.)';
    SQL
  end

  def down
    # Remove check constraints
    remove_check_constraint :product_configurations, name: 'product_configurations_quantity_range'
    remove_check_constraint :product_configurations, name: 'product_configurations_position_range'

    # Remove indexes
    remove_index :product_configurations, name: 'index_pc_on_super_and_position'
    remove_index :product_configurations, name: 'index_pc_on_sub_and_super'
    remove_index :product_configurations, name: 'index_pc_on_quantity'

    # Migrate quantity back to JSONB before removing column
    execute <<-SQL
      UPDATE product_configurations
      SET info = jsonb_set(info, '{quantity}', to_jsonb(quantity))
      WHERE quantity != 1;
    SQL

    # Remove quantity column
    remove_column :product_configurations, :quantity
  end
end
