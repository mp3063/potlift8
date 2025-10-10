class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.jsonb :info, default: {}, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :companies, :code, unique: true
  end
end
