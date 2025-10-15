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

ActiveRecord::Schema[8.0].define(version: 2025_10_15_140300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attribute_groups", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.text "description"
    t.integer "position"
    t.jsonb "info", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_attribute_groups_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_attribute_groups_on_company_id"
  end

  create_table "catalog_item_attribute_values", force: :cascade do |t|
    t.bigint "catalog_item_id", null: false
    t.bigint "product_attribute_id", null: false
    t.text "value"
    t.jsonb "info", default: {}
    t.boolean "ready", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_item_id", "product_attribute_id"], name: "ciav_index", unique: true
  end

  create_table "catalog_items", force: :cascade do |t|
    t.bigint "catalog_id", null: false
    t.bigint "product_id", null: false
    t.integer "priority"
    t.integer "catalog_item_state", default: 0, null: false
    t.jsonb "info", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_id", "product_id"], name: "index_catalog_items_on_catalog_id_and_product_id", unique: true
    t.index ["catalog_item_state"], name: "index_catalog_items_on_catalog_item_state"
    t.index ["priority"], name: "index_catalog_items_on_priority"
  end

  create_table "catalogs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.integer "catalog_type", null: false
    t.string "currency_code", default: "eur", null: false
    t.jsonb "info", default: {}
    t.jsonb "cache", default: {}
    t.bigint "sync_lock_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_type"], name: "index_catalogs_on_catalog_type"
    t.index ["company_id", "code"], name: "index_catalogs_on_company_id_and_code", unique: true
    t.index ["currency_code"], name: "index_catalogs_on_currency_code"
    t.index ["sync_lock_id"], name: "index_catalogs_on_sync_lock_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.jsonb "info", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "authlift_id"
    t.string "api_token"
    t.index ["api_token"], name: "index_companies_on_api_token", unique: true
    t.index ["authlift_id"], name: "index_companies_on_authlift_id", unique: true
    t.index ["code"], name: "index_companies_on_code", unique: true
  end

  create_table "company_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_memberships_on_company_id"
    t.index ["user_id", "company_id"], name: "index_company_memberships_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_company_memberships_on_user_id"
  end

  create_table "company_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.string "code", null: false
    t.string "state"
    t.index ["company_id", "code"], name: "index_company_states_on_company_id_and_code", unique: true
  end

  create_table "configuration_values", comment: "Values for configuration dimensions (Small/Medium/Large for Size, Red/Blue for Color)", force: :cascade do |t|
    t.bigint "configuration_id", null: false, comment: "Parent configuration dimension"
    t.string "value", limit: 100, null: false, comment: "Display value shown to users"
    t.integer "position", default: 1, null: false, comment: "Display order (1 = first option)"
    t.jsonb "info", default: {}, null: false, comment: "JSONB: color_hex (#FF0000), image_url, price_modifier (+10), stock_status, sku_suffix"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["configuration_id", "position"], name: "index_configuration_values_on_config_and_position", comment: "Optimizes ordered value retrieval for a dimension"
    t.index ["configuration_id", "value"], name: "index_configuration_values_on_config_and_value", unique: true, comment: "Ensures unique values per configuration dimension"
    t.index ["configuration_id"], name: "index_configuration_values_on_configuration_id"
    t.index ["info"], name: "index_configuration_values_on_info", using: :gin, comment: "Supports JSONB queries on value metadata"
    t.index ["value"], name: "index_configuration_values_on_value", comment: "Optimizes value search and filtering"
    t.check_constraint "\"position\" > 0 AND \"position\" < 1000", name: "configuration_values_position_range"
    t.check_constraint "value::text <> ''::text", name: "configuration_values_value_not_empty"
  end

  create_table "configurations", comment: "Configuration dimensions for variant products (Size, Color, Material, etc.)", force: :cascade do |t|
    t.bigint "company_id", null: false, comment: "Multi-tenant isolation - SECURITY CRITICAL"
    t.bigint "product_id", null: false, comment: "Parent configurable product"
    t.string "name", limit: 100, null: false, comment: "User-facing dimension name"
    t.string "code", limit: 50, null: false, comment: "System code for API/integration use"
    t.integer "position", default: 1, null: false, comment: "Display order (1 = first dimension)"
    t.jsonb "info", default: {}, null: false, comment: "JSONB: display_type (dropdown/swatch/button), validation_rules, ui_settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "product_id"], name: "index_configurations_on_company_and_product", comment: "Supports multi-tenant product configuration queries"
    t.index ["company_id"], name: "index_configurations_on_company_id"
    t.index ["info"], name: "index_configurations_on_info", using: :gin, comment: "Supports JSONB queries on configuration metadata"
    t.index ["product_id", "code"], name: "index_configurations_on_product_and_code", unique: true, comment: "Ensures unique dimension codes per product"
    t.index ["product_id", "position"], name: "index_configurations_on_product_and_position", comment: "Optimizes ordered configuration dimension retrieval"
    t.index ["product_id"], name: "index_configurations_on_product_id"
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
    t.index ["product_id", "storage_id", "value"], name: "index_inventories_on_product_storage_value", comment: "Optimizes inventory lookups and saldo calculations"
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
    t.index ["company_id", "label_type", "parent_label_id"], name: "index_labels_on_company_type_parent", comment: "Optimizes label filtering and hierarchy traversal"
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
    t.index ["product_id", "product_attribute_id", "value"], name: "index_pav_on_product_attribute_value", comment: "Optimizes product attribute value searches with covering index"
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
    t.bigint "attribute_group_id"
    t.index ["attribute_group_id"], name: "index_product_attributes_on_attribute_group_id"
    t.index ["company_id", "code"], name: "index_product_attributes_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_product_attributes_on_company_id"
  end

  create_table "product_configurations", comment: "Links products to their variants (configurable) or components (bundle). Single source of truth for all product relationships.", force: :cascade do |t|
    t.bigint "superproduct_id", null: false
    t.bigint "subproduct_id", null: false
    t.integer "configuration_position", comment: "Display order within parent product"
    t.jsonb "info", default: {}, null: false, comment: "JSONB: Additional metadata (price_modifier, discount, notes, etc.)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity", default: 1, null: false, comment: "Number of units for bundle components (always 1 for variants)"
    t.index ["quantity"], name: "index_pc_on_quantity", where: "(quantity > 1)", comment: "Optimizes bundle component quantity queries"
    t.index ["subproduct_id", "superproduct_id"], name: "index_pc_on_sub_and_super", comment: "Optimizes reverse lookup to find parent products"
    t.index ["subproduct_id"], name: "index_product_configurations_on_subproduct_id"
    t.index ["superproduct_id", "configuration_position"], name: "index_pc_on_super_and_position", comment: "Optimizes ordered variant/component retrieval for parent product"
    t.index ["superproduct_id", "subproduct_id"], name: "index_product_configs_on_super_and_sub", unique: true
    t.index ["superproduct_id"], name: "index_product_configurations_on_superproduct_id"
    t.check_constraint "configuration_position > 0 AND configuration_position < 10000", name: "product_configurations_position_range"
    t.check_constraint "quantity > 0 AND quantity <= 10000", name: "product_configurations_quantity_range"
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
    t.index ["company_id", "product_status", "product_type"], name: "index_products_on_company_status_type", comment: "Optimizes product filtering by company, status, and type"
    t.index ["company_id", "sku"], name: "products_company_sku_unique_index", unique: true
    t.index ["company_id", "updated_at"], name: "index_products_on_company_updated_at", comment: "Optimizes product sorting by updated_at within company scope"
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["product_status"], name: "index_products_on_product_status"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sync_lock_id"], name: "index_products_on_sync_lock_id"
  end

  create_table "related_products", comment: "Product relationships for cross-sell, upsell, alternatives, accessories, etc.", force: :cascade do |t|
    t.bigint "product_id", null: false, comment: "Source product"
    t.bigint "related_to_id", null: false, comment: "Target product (related/recommended)"
    t.integer "relation_type", default: 0, null: false, comment: "Enum: 0=cross_sell, 1=upsell, 2=alternative, 3=accessory, 4=related, 5=similar"
    t.integer "position", default: 1, null: false, comment: "Display order within relation type"
    t.jsonb "info", default: {}, null: false, comment: "JSONB: discount_percentage, display_condition, promotion_text, visibility_rules"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["info"], name: "index_related_products_on_info", using: :gin, comment: "Supports JSONB queries on relationship metadata"
    t.index ["product_id", "related_to_id", "relation_type"], name: "index_related_products_unique_relation", unique: true, comment: "Ensures unique product relationships per type"
    t.index ["product_id", "relation_type", "position"], name: "index_related_products_on_product_type_position", comment: "Optimizes ordered related product retrieval by type"
    t.index ["product_id"], name: "index_related_products_on_product_id"
    t.index ["related_to_id", "relation_type"], name: "index_related_products_on_related_to_and_type", comment: "Optimizes reverse lookups (which products reference this one)"
    t.index ["related_to_id"], name: "index_related_products_on_related_to_id"
    t.index ["relation_type"], name: "index_related_products_on_relation_type", comment: "Optimizes queries filtering by relation type"
    t.check_constraint "\"position\" > 0 AND \"position\" < 1000", name: "related_products_position_range"
    t.check_constraint "product_id <> related_to_id", name: "related_products_no_self_reference"
    t.check_constraint "relation_type >= 0 AND relation_type <= 5", name: "related_products_relation_type_range"
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

  create_table "users", force: :cascade do |t|
    t.string "oauth_sub", null: false
    t.string "email", null: false
    t.string "name"
    t.datetime "last_sign_in_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["oauth_sub"], name: "index_users_on_oauth_sub", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attribute_groups", "companies"
  add_foreign_key "catalog_item_attribute_values", "catalog_items"
  add_foreign_key "catalog_item_attribute_values", "product_attributes"
  add_foreign_key "catalog_items", "catalogs"
  add_foreign_key "catalog_items", "products"
  add_foreign_key "catalogs", "companies"
  add_foreign_key "catalogs", "sync_locks"
  add_foreign_key "company_memberships", "companies"
  add_foreign_key "company_memberships", "users"
  add_foreign_key "company_states", "companies"
  add_foreign_key "configuration_values", "configurations", on_delete: :cascade
  add_foreign_key "configurations", "companies", on_delete: :cascade
  add_foreign_key "configurations", "products", on_delete: :cascade
  add_foreign_key "inventories", "products"
  add_foreign_key "inventories", "storages"
  add_foreign_key "labels", "companies"
  add_foreign_key "labels", "labels", column: "parent_label_id"
  add_foreign_key "product_assets", "products"
  add_foreign_key "product_attribute_values", "product_attributes"
  add_foreign_key "product_attribute_values", "products"
  add_foreign_key "product_attributes", "attribute_groups"
  add_foreign_key "product_attributes", "companies"
  add_foreign_key "product_configurations", "products", column: "subproduct_id"
  add_foreign_key "product_configurations", "products", column: "superproduct_id"
  add_foreign_key "product_labels", "labels"
  add_foreign_key "product_labels", "products"
  add_foreign_key "products", "companies"
  add_foreign_key "products", "sync_locks"
  add_foreign_key "related_products", "products", column: "related_to_id", on_delete: :cascade
  add_foreign_key "related_products", "products", on_delete: :cascade
  add_foreign_key "storages", "companies"
  add_foreign_key "users", "companies"
end
