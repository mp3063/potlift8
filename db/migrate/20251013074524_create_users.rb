class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :oauth_sub, null: false
      t.string :email, null: false
      t.string :name
      t.datetime :last_sign_in_at
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
    add_index :users, :oauth_sub, unique: true
    add_index :users, :email, unique: true
  end
end
