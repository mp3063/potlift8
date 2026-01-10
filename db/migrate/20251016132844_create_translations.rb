class CreateTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :translations do |t|
      t.references :translatable, polymorphic: true, null: false
      t.string :locale, null: false
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    # Composite unique index for translations
    add_index :translations, [ :translatable_type, :translatable_id, :locale, :key ],
              unique: true,
              name: 'index_translations_on_translatable_and_locale_and_key'

    # Index for lookup by locale
    add_index :translations, :locale
  end
end
