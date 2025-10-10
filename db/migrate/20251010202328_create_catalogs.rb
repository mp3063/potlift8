class CreateCatalogs < ActiveRecord::Migration[8.0]
  def change
    create_table :catalogs do |t|  # Standard bigint
      t.references :company, null: false, foreign_key: true, index: false
      t.string :code, null: false
      t.string :name, null: false
      t.integer :catalog_type, null: false
      t.string :currency_code, default: 'eur', null: false
      t.jsonb :info, default: {}  # pot3 uses 'info', not 'settings'
      t.jsonb :cache, default: {}  # pot3 has this
      t.references :sync_lock, foreign_key: true  # pot3 has this
      t.timestamps

      t.index [:company_id, :code], unique: true
      t.index :catalog_type
      t.index :currency_code
    end
  end
end
