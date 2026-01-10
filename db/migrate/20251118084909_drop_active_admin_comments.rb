class DropActiveAdminComments < ActiveRecord::Migration[8.0]
  def up
    # Drop unused active_admin_comments table
    # This table was never used - no ActiveAdmin gem, no model, no associations
    drop_table :active_admin_comments, if_exists: true
  end

  def down
    # Recreate table structure for rollback (though this was never actually used)
    create_table :active_admin_comments do |t|
      t.string :namespace
      t.text :body
      t.string :resource_type
      t.bigint :resource_id
      t.string :author_type
      t.bigint :author_id
      t.timestamps
    end

    add_index :active_admin_comments, [ :namespace ]
    add_index :active_admin_comments, [ :author_type, :author_id ]
    add_index :active_admin_comments, [ :resource_type, :resource_id ]
  end
end
