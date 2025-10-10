class AddAuthliftIdToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :authlift_id, :integer
    add_index :companies, :authlift_id, unique: true
  end
end
