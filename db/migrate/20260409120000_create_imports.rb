class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :imports do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :import_type, null: false, default: "products"
      t.string :status, null: false, default: "pending"
      t.integer :progress, null: false, default: 0
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.jsonb :errors_data, null: false, default: []
      t.string :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :imports, [ :company_id, :created_at ]
    add_index :imports, :status
  end
end
