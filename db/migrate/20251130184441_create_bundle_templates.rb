class CreateBundleTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :bundle_templates do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.references :company, null: false, foreign_key: true
      t.jsonb :configuration, default: {}, null: false
      t.integer :generated_variants_count, default: 0, null: false
      t.datetime :last_generated_at

      t.timestamps
    end
  end
end
