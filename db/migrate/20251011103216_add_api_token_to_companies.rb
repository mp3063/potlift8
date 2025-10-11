class AddApiTokenToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :api_token, :string
    add_index :companies, :api_token, unique: true
  end
end
