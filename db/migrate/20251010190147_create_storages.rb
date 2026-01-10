class CreateStorages < ActiveRecord::Migration[8.0]
  def change
    create_table :storages do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :storage_type, null: false
      t.string :code, null: false
      t.string :name
      t.jsonb :info, default: {}, null: false
      t.boolean :default, default: false
      t.integer :storage_position
      t.integer :storage_status, default: 1, null: false

      t.timestamps
    end

    add_index :storages, [ :company_id, :code ], unique: true, name: 'storages_company_code_unique_index'
  end
end
