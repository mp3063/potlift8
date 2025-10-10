class CreateSyncLocks < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_locks do |t|
      t.string :timestamp

      t.timestamps
    end
  end
end
