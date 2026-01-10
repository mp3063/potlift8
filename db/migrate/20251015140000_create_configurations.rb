class CreateConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :configurations do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 100, comment: 'Display name: Size, Color, Material'
      t.string :code, null: false, limit: 50, comment: 'Machine-readable code: size, color, material'
      t.integer :position, null: false, default: 1, comment: 'Display order within product'
      t.jsonb :info, default: {}, null: false, comment: 'Metadata: display_type, validation_rules, etc.'
      t.timestamps

      # Performance: Ordered retrieval of configurations for a product
      t.index [ :product_id, :position ],
              name: 'index_configurations_on_product_and_position',
              comment: 'Optimizes ordered configuration dimension retrieval'

      # Uniqueness: Prevent duplicate dimension codes per product
      t.index [ :product_id, :code ],
              unique: true,
              name: 'index_configurations_on_product_and_code',
              comment: 'Ensures unique dimension codes per product'

      # Multi-tenancy: Scoped queries by company
      t.index [ :company_id, :product_id ],
              name: 'index_configurations_on_company_and_product',
              comment: 'Supports multi-tenant product configuration queries'

      # JSONB indexing for common info queries
      t.index :info,
              using: :gin,
              name: 'index_configurations_on_info',
              comment: 'Supports JSONB queries on configuration metadata'
    end

    # Add comments for documentation
    reversible do |dir|
      dir.up do
        execute <<-SQL
          COMMENT ON TABLE configurations IS 'Configuration dimensions for variant products (Size, Color, Material, etc.)';
          COMMENT ON COLUMN configurations.company_id IS 'Multi-tenant isolation - SECURITY CRITICAL';
          COMMENT ON COLUMN configurations.product_id IS 'Parent configurable product';
          COMMENT ON COLUMN configurations.name IS 'User-facing dimension name';
          COMMENT ON COLUMN configurations.code IS 'System code for API/integration use';
          COMMENT ON COLUMN configurations.position IS 'Display order (1 = first dimension)';
          COMMENT ON COLUMN configurations.info IS 'JSONB: display_type (dropdown/swatch/button), validation_rules, ui_settings';
        SQL
      end
    end
  end
end
