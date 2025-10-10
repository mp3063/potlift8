# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_10_191157) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.jsonb "info", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "authlift_id"
    t.index ["authlift_id"], name: "index_companies_on_authlift_id", unique: true
    t.index ["code"], name: "index_companies_on_code", unique: true
  end

  create_table "company_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.string "code", null: false
    t.string "state"
    t.index ["company_id", "code"], name: "index_company_states_on_company_id_and_code", unique: true
  end

  create_table "inventories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "storage_id", null: false
    t.integer "value", default: 0, null: false
    t.jsonb "info", default: {}, null: false
    t.boolean "default", default: false
    t.date "eta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "storage_id"], name: "inventories_product_storage_unique_index", unique: true
    t.index ["product_id"], name: "index_inventories_on_product_id"
    t.index ["storage_id"], name: "index_inventories_on_storage_id"
  end

  create_table "labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.string "label_type", null: false
    t.string "code", null: false
    t.string "full_code", null: false
    t.string "name", null: false
    t.string "full_name", null: false
    t.string "description"
    t.jsonb "info", default: {}, null: false
    t.bigint "parent_label_id"
    t.integer "label_positions"
    t.integer "product_default_restriction", default: 1
    t.index ["company_id", "full_code"], name: "index_labels_on_company_id_and_full_code", unique: true
    t.index ["company_id"], name: "index_labels_on_company_id"
    t.index ["parent_label_id"], name: "index_labels_on_parent_label_id"
  end

  create_table "product_assets", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "name"
    t.integer "product_asset_type", null: false
    t.integer "asset_priority"
    t.integer "asset_visibility"
    t.text "asset_description"
    t.jsonb "info", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "asset_priority"], name: "index_product_assets_on_product_id_and_priority"
    t.index ["product_id"], name: "index_product_assets_on_product_id"
  end

  create_table "product_attribute_values", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "product_attribute_id", null: false
    t.text "value"
    t.jsonb "info", default: {}, null: false
    t.boolean "ready", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_attribute_id"], name: "index_product_attribute_values_on_product_attribute_id"
    t.index ["product_id", "product_attribute_id"], name: "pavs_index", unique: true
    t.index ["product_id"], name: "index_product_attribute_values_on_product_id"
  end

  create_table "product_attributes", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "pa_type", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "description"
    t.boolean "mandatory", default: false, null: false
    t.string "default_value"
    t.jsonb "info", default: {}, null: false
    t.integer "view_format", default: 0, null: false
    t.integer "attribute_position"
    t.integer "product_attribute_scope", default: 0, null: false
    t.boolean "localizable", default: false, null: false
    t.boolean "subproduct_mandatory", default: false, null: false
    t.jsonb "rules", default: {}, null: false
    t.boolean "has_rules", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_product_attributes_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_product_attributes_on_company_id"
  end

  create_table "product_labels", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["label_id"], name: "index_product_labels_on_label_id"
    t.index ["product_id", "label_id"], name: "index_product_labels_on_product_id_and_label_id", unique: true
    t.index ["product_id"], name: "index_product_labels_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.bigint "sync_lock_id"
    t.string "sku", null: false
    t.string "name", null: false
    t.string "ean"
    t.integer "product_type", null: false
    t.integer "configuration_type"
    t.jsonb "structure", default: {}, null: false
    t.jsonb "info", default: {}, null: false
    t.jsonb "cache", default: {}, null: false
    t.integer "product_status"
    t.index ["company_id", "sku"], name: "products_company_sku_unique_index", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["product_status"], name: "index_products_on_product_status"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sync_lock_id"], name: "index_products_on_sync_lock_id"
  end

  create_table "storages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.integer "storage_type", null: false
    t.string "code", null: false
    t.string "name"
    t.jsonb "info", default: {}, null: false
    t.boolean "default", default: false
    t.integer "storage_position"
    t.integer "storage_status", default: 1, null: false
    t.index ["company_id", "code"], name: "storages_company_code_unique_index", unique: true
    t.index ["company_id"], name: "index_storages_on_company_id"
  end

  create_table "sync_locks", force: :cascade do |t|
    t.string "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "company_states", "companies"
  add_foreign_key "inventories", "products"
  add_foreign_key "inventories", "storages"
  add_foreign_key "labels", "companies"
  add_foreign_key "labels", "labels", column: "parent_label_id"
  add_foreign_key "product_assets", "products"
  add_foreign_key "product_attribute_values", "product_attributes"
  add_foreign_key "product_attribute_values", "products"
  add_foreign_key "product_attributes", "companies"
  add_foreign_key "product_labels", "labels"
  add_foreign_key "product_labels", "products"
  add_foreign_key "products", "companies"
  add_foreign_key "products", "sync_locks"
  add_foreign_key "storages", "companies"
end
