class AddFieldsToStorages < ActiveRecord::Migration[8.0]
  def change
    add_reference :storages, :company, null: false, foreign_key: true, index: true
    add_column :storages, :storage_type, :integer, null: false
    add_column :storages, :code, :string, null: false
    add_column :storages, :name, :string
    add_column :storages, :info, :jsonb, default: {}, null: false
    add_column :storages, :default, :boolean, default: false
    add_column :storages, :storage_position, :integer
    add_column :storages, :storage_status, :integer, default: 1, null: false

    add_index :storages, [:company_id, :code], unique: true, name: 'storages_company_code_unique_index'
  end
end
