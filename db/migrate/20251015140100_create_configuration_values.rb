class CreateConfigurationValues < ActiveRecord::Migration[8.0]
  def change
    create_table :configuration_values do |t|
      t.references :configuration, null: false, foreign_key: { on_delete: :cascade }
      t.string :value, null: false, limit: 100, comment: 'Value: Small, Red, Cotton, etc.'
      t.integer :position, null: false, default: 1, comment: 'Display order within configuration'
      t.jsonb :info, default: {}, null: false, comment: 'Metadata: color_hex, image_url, price_modifier, etc.'
      t.timestamps

      # Performance: Ordered retrieval of values for a configuration dimension
      t.index [ :configuration_id, :position ],
              name: 'index_configuration_values_on_config_and_position',
              comment: 'Optimizes ordered value retrieval for a dimension'

      # Uniqueness: Prevent duplicate values per configuration
      t.index [ :configuration_id, :value ],
              unique: true,
              name: 'index_configuration_values_on_config_and_value',
              comment: 'Ensures unique values per configuration dimension'

      # JSONB indexing for common info queries
      t.index :info,
              using: :gin,
              name: 'index_configuration_values_on_info',
              comment: 'Supports JSONB queries on value metadata'

      # Performance: Full-text search on values
      t.index :value,
              name: 'index_configuration_values_on_value',
              comment: 'Optimizes value search and filtering'
    end

    # Add check constraint to prevent empty values
    add_check_constraint :configuration_values,
                         "value <> ''",
                         name: 'configuration_values_value_not_empty',
                         comment: 'Prevents empty string values'

    # Add check constraint for reasonable position values
    add_check_constraint :configuration_values,
                         "position > 0 AND position < 1000",
                         name: 'configuration_values_position_range',
                         comment: 'Ensures position is between 1 and 999'

    # Add comments for documentation
    reversible do |dir|
      dir.up do
        execute <<-SQL
          COMMENT ON TABLE configuration_values IS 'Values for configuration dimensions (Small/Medium/Large for Size, Red/Blue for Color)';
          COMMENT ON COLUMN configuration_values.configuration_id IS 'Parent configuration dimension';
          COMMENT ON COLUMN configuration_values.value IS 'Display value shown to users';
          COMMENT ON COLUMN configuration_values.position IS 'Display order (1 = first option)';
          COMMENT ON COLUMN configuration_values.info IS 'JSONB: color_hex (#FF0000), image_url, price_modifier (+10), stock_status, sku_suffix';
        SQL
      end
    end
  end
end
