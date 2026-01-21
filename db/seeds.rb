# db/seeds.rb
# Comprehensive seed data for Potlift8 - Cannabis Inventory Management
#
# Usage:
#   rails db:seed
#   or
#   rails db:reset (drops, creates, migrates, and seeds)

require 'factory_bot_rails'

puts "🌱 Starting Potlift8 seed process..."
puts "=" * 80

# Clean existing data (optional - comment out if you want to preserve data)
# WARNING: This will delete ALL data except Company records
if Rails.env.development? && ENV['CLEAN_SEED'] == 'true'
  puts "\n🗑️  Cleaning existing data (keeping Company records)..."

  [ ProductAttributeValue, ProductLabel, CatalogItem, Inventory,
   Product, ProductAttribute, AttributeGroup, Label,
   Catalog, Storage ].each do |model|
    count = model.count
    model.destroy_all
    puts "   Deleted #{count} #{model.name.pluralize}"
  end

  puts "\n   ℹ️  Preserving Company records"
  puts "   ℹ️  To clean everything, run: rails db:reset"
end

# ============================================================================
# 1. CREATE COMPANY
# ============================================================================
puts "\n🏢 Creating Company..."

# Use OZZ company code to match Authlift8 company (ID: 10)
# When you log in with superadmin@authlift.com and select OZZ company,
# this will be the matching Potlift8 company
company = Company.find_or_initialize_by(code: 'OZZ')
company.assign_attributes(
  name: 'Ozz Cannabis Co.',
  info: {
    'timezone' => 'America/Los_Angeles',
    'currency' => 'USD',
    'license_number' => 'CA-MC-2024-001',
    'settings' => {
      'notifications' => true,
      'theme' => 'light',
      'multi_currency' => true
    }
  },
  active: true,
  # API token for Shopify8 sync (must match Company.api_token in Shopify8)
  api_token: 'b2b9c829eecd344d688a01b13035ce938823d8d5bcbb689501ebfc2502d4bbba'
)
company.save!

puts "   ✓ Created company: #{company.name} (#{company.code})"

# ============================================================================
# 2. CREATE STORAGES
# ============================================================================
puts "\n📦 Creating Storages..."

storages = []

storages << FactoryBot.create(:storage,
  company: company,
  code: 'MAIN',
  name: 'Main Warehouse',
  storage_type: :regular,
  storage_status: :active,
  default: true,
  storage_position: 1,
  info: {
    'location' => 'Oakland, CA',
    'capacity' => 5000,
    'climate_controlled' => true
  }
)

storages << FactoryBot.create(:storage,
  company: company,
  code: 'RETAIL',
  name: 'Retail Floor',
  storage_type: :regular,
  storage_status: :active,
  storage_position: 2,
  info: {
    'location' => 'Dispensary Front',
    'capacity' => 500,
    'display_ready' => true
  }
)

storages << FactoryBot.create(:storage,
  company: company,
  code: 'TEMP',
  name: 'Temporary Storage',
  storage_type: :temporary,
  storage_status: :active,
  storage_position: 3,
  info: {
    'location' => 'Receiving Area',
    'capacity' => 1000
  }
)

storages << FactoryBot.create(:storage,
  company: company,
  code: 'INCOMING',
  name: 'Incoming Shipments',
  storage_type: :incoming,
  storage_status: :active,
  storage_position: 4,
  info: {
    'location' => 'Loading Dock',
    'capacity' => 800
  }
)

storages << FactoryBot.create(:storage,
  company: company,
  code: 'VAULT',
  name: 'Secure Vault',
  storage_type: :regular,
  storage_status: :active,
  storage_position: 5,
  info: {
    'location' => 'Secure Area',
    'capacity' => 200,
    'high_security' => true,
    'access_restricted' => true
  }
)

puts "   ✓ Created #{storages.count} storages"
storages.each { |s| puts "      - #{s.name} (#{s.code})" }

# ============================================================================
# 3. CREATE CATALOGS
# ============================================================================
puts "\n📚 Creating Catalogs..."

catalogs = []

catalogs << FactoryBot.create(:catalog,
  company: company,
  code: 'WEB-EUR',
  name: 'European Webshop',
  catalog_type: :webshop,
  currency_code: 'eur',
  info: {
    'description' => 'Main European online catalog',
    'region' => 'EU',
    'tax_rate' => 0.21,
    'shipping_regions' => [ 'DE', 'NL', 'FR', 'ES' ],
    # Shopify8 sync configuration
    'sync_target' => 'shopify8',
    'shopify_api_token' => 'b2b9c829eecd344d688a01b13035ce938823d8d5bcbb689501ebfc2502d4bbba'
  }
)

catalogs << FactoryBot.create(:catalog,
  company: company,
  code: 'WEB-SEK',
  name: 'Swedish Webshop',
  catalog_type: :webshop,
  currency_code: 'sek',
  info: {
    'description' => 'Swedish online catalog',
    'region' => 'Scandinavia',
    'tax_rate' => 0.25,
    'shipping_regions' => [ 'SE' ]
  }
)

catalogs << FactoryBot.create(:catalog,
  company: company,
  code: 'WEB-NOK',
  name: 'Norwegian Webshop',
  catalog_type: :webshop,
  currency_code: 'nok',
  info: {
    'description' => 'Norwegian online catalog',
    'region' => 'Scandinavia',
    'tax_rate' => 0.25,
    'shipping_regions' => [ 'NO' ]
  }
)

catalogs << FactoryBot.create(:catalog,
  company: company,
  code: 'SUPPLY',
  name: 'Supply Catalog',
  catalog_type: :supply,
  currency_code: 'eur',
  info: {
    'description' => 'B2B supply catalog for dispensaries',
    'region' => 'Global',
    'wholesale' => true
  }
)

puts "   ✓ Created #{catalogs.count} catalogs"
catalogs.each { |c| puts "      - #{c.name} (#{c.code}, #{c.currency_code.upcase})" }

# ============================================================================
# 4. CREATE PRODUCT ATTRIBUTES
# ============================================================================
puts "\n📋 Creating Product Attributes..."

attributes = {}

# Pricing Group
pricing_group = FactoryBot.create(:attribute_group,
  company: company,
  code: 'pricing',
  name: 'Pricing Information'
)

attributes[:price] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'price',
  name: 'Price',
  pa_type: :patype_number,
  view_format: :view_format_price,
  product_attribute_scope: :product_and_catalog_scope,
  mandatory: true,
  has_rules: true,
  rules: [ 'positive', 'not_null' ],
  attribute_group: pricing_group,
  attribute_position: 1
)

attributes[:cost] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'cost',
  name: 'Cost Price',
  pa_type: :patype_number,
  view_format: :view_format_price,
  product_attribute_scope: :product_scope,
  mandatory: false,
  has_rules: true,
  rules: [ 'positive' ],
  attribute_group: pricing_group,
  attribute_position: 2
)

# Product Details Group
details_group = FactoryBot.create(:attribute_group,
  company: company,
  code: 'details',
  name: 'Product Details'
)

attributes[:description] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'description',
  name: 'Description',
  pa_type: :patype_rich_text,
  view_format: :view_format_html,
  product_attribute_scope: :product_and_catalog_scope,
  mandatory: true,
  attribute_group: details_group,
  attribute_position: 1
)

attributes[:short_description] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'short_description',
  name: 'Short Description',
  pa_type: :patype_text,
  view_format: :view_format_general,
  product_attribute_scope: :product_and_catalog_scope,
  mandatory: false,
  attribute_group: details_group,
  attribute_position: 2
)

# Cannabis-Specific Attributes Group
cannabis_group = FactoryBot.create(:attribute_group,
  company: company,
  code: 'cannabis',
  name: 'Cannabis Properties'
)

attributes[:thc_percentage] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'thc_percentage',
  name: 'THC %',
  pa_type: :patype_number,
  view_format: :view_format_general,
  product_attribute_scope: :product_scope,
  mandatory: false,
  has_rules: false,
  rules: [],
  attribute_group: cannabis_group,
  attribute_position: 1,
  info: { 'unit' => '%', 'max' => 35, 'min' => 0 }
)

attributes[:cbd_percentage] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'cbd_percentage',
  name: 'CBD %',
  pa_type: :patype_number,
  view_format: :view_format_general,
  product_attribute_scope: :product_scope,
  mandatory: false,
  has_rules: false,
  rules: [],
  attribute_group: cannabis_group,
  attribute_position: 2,
  info: { 'unit' => '%', 'max' => 25, 'min' => 0 }
)

attributes[:strain_type] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'strain_type',
  name: 'Strain Type',
  pa_type: :patype_select,
  view_format: :view_format_selectable,
  product_attribute_scope: :product_scope,
  mandatory: false,
  attribute_group: cannabis_group,
  attribute_position: 3,
  info: {
    'options' => [ 'Indica', 'Sativa', 'Hybrid', 'CBD-Dominant' ]
  }
)

attributes[:terpene_profile] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'terpene_profile',
  name: 'Dominant Terpenes',
  pa_type: :patype_multiselect,
  view_format: :view_format_selectable,
  product_attribute_scope: :product_scope,
  mandatory: false,
  attribute_group: cannabis_group,
  attribute_position: 4,
  info: {
    'options' => [ 'Myrcene', 'Limonene', 'Caryophyllene', 'Pinene', 'Linalool', 'Humulene' ]
  }
)

# Physical Properties Group
physical_group = FactoryBot.create(:attribute_group,
  company: company,
  code: 'physical',
  name: 'Physical Properties'
)

attributes[:weight] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'weight',
  name: 'Weight',
  pa_type: :patype_number,
  view_format: :view_format_weight,
  product_attribute_scope: :product_scope,
  mandatory: false,
  has_rules: false,
  rules: [],
  attribute_group: physical_group,
  attribute_position: 1,
  info: { 'unit' => 'g', 'min' => 0.1 }
)

attributes[:package_size] = FactoryBot.create(:product_attribute,
  company: company,
  code: 'package_size',
  name: 'Package Size',
  pa_type: :patype_select,
  view_format: :view_format_selectable,
  product_attribute_scope: :product_scope,
  mandatory: false,
  attribute_group: physical_group,
  attribute_position: 2,
  info: {
    'options' => [ '1g', '3.5g', '7g', '14g', '28g', '100mg', '250mg', '500mg' ]
  }
)

puts "   ✓ Created #{attributes.count} product attributes"
attributes.each { |key, attr| puts "      - #{attr.name} (#{attr.code})" }

# ============================================================================
# 5. CREATE LABEL HIERARCHY (Categories)
# ============================================================================
puts "\n🏷️  Creating Label Hierarchy..."

labels = {}

# Root categories
labels[:flower] = FactoryBot.create(:label,
  company: company,
  code: 'flower',
  name: 'Flower',
  label_type: 'category',
  description: 'Premium cannabis flower products',
  label_positions: 1
)

labels[:flower_indica] = FactoryBot.create(:label,
  company: company,
  code: 'flower_indica',
  name: 'Indica',
  label_type: 'category',
  parent_label: labels[:flower],
  label_positions: 1
)

labels[:flower_sativa] = FactoryBot.create(:label,
  company: company,
  code: 'flower_sativa',
  name: 'Sativa',
  label_type: 'category',
  parent_label: labels[:flower],
  label_positions: 2
)

labels[:flower_hybrid] = FactoryBot.create(:label,
  company: company,
  code: 'flower_hybrid',
  name: 'Hybrid',
  label_type: 'category',
  parent_label: labels[:flower],
  label_positions: 3
)

labels[:prerolls] = FactoryBot.create(:label,
  company: company,
  code: 'prerolls',
  name: 'Pre-Rolls',
  label_type: 'category',
  description: 'Ready-to-smoke pre-rolled cannabis',
  label_positions: 2
)

labels[:edibles] = FactoryBot.create(:label,
  company: company,
  code: 'edibles',
  name: 'Edibles',
  label_type: 'category',
  description: 'Cannabis-infused food products',
  label_positions: 3
)

labels[:edibles_gummies] = FactoryBot.create(:label,
  company: company,
  code: 'edibles_gummies',
  name: 'Gummies',
  label_type: 'category',
  parent_label: labels[:edibles],
  label_positions: 1
)

labels[:edibles_chocolates] = FactoryBot.create(:label,
  company: company,
  code: 'edibles_chocolates',
  name: 'Chocolates',
  label_type: 'category',
  parent_label: labels[:edibles],
  label_positions: 2
)

labels[:edibles_baked] = FactoryBot.create(:label,
  company: company,
  code: 'edibles_baked',
  name: 'Baked Goods',
  label_type: 'category',
  parent_label: labels[:edibles],
  label_positions: 3
)

labels[:concentrates] = FactoryBot.create(:label,
  company: company,
  code: 'concentrates',
  name: 'Concentrates',
  label_type: 'category',
  description: 'Cannabis extracts and concentrates',
  label_positions: 4
)

labels[:vapes] = FactoryBot.create(:label,
  company: company,
  code: 'vapes',
  name: 'Vaporizers',
  label_type: 'category',
  description: 'Vape cartridges and disposables',
  label_positions: 5
)

labels[:topicals] = FactoryBot.create(:label,
  company: company,
  code: 'topicals',
  name: 'Topicals',
  label_type: 'category',
  description: 'Cannabis-infused topical products',
  label_positions: 6
)

# Brand labels
labels[:brand_greenleaf] = FactoryBot.create(:label,
  company: company,
  code: 'brand_greenleaf',
  name: 'GreenLeaf Select',
  label_type: 'brand',
  description: 'House brand premium products'
)

labels[:brand_pure] = FactoryBot.create(:label,
  company: company,
  code: 'brand_pure',
  name: 'Pure Essence',
  label_type: 'brand',
  description: 'Organic craft cannabis'
)

puts "   ✓ Created #{labels.count} labels"
puts "      Categories: #{labels.values.count { |l| l.label_type == 'category' }}"
puts "      Brands: #{labels.values.count { |l| l.label_type == 'brand' }}"

# ============================================================================
# 6. CREATE PRODUCTS (50+)
# ============================================================================
puts "\n🌿 Creating Products..."

products = []

# Helper method to create product with all associations
def create_product(company:, sku:, name:, description:, price:, cost:, thc:, cbd:, strain:, weight:,
                   package_size:, terpenes:, labels:, storages:, product_status: :active)
  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: name,
    product_type: :sellable,
    product_status: product_status,
    info: {
      'brand' => labels.find { |l| l.label_type == 'brand' }&.name,
      'lab_tested' => true,
      'organic' => [ true, false ].sample
    }
  )

  product
end

# -------------------------
# FLOWER PRODUCTS (20)
# -------------------------
puts "\n   Creating Flower products..."

flower_products = [
  { name: 'Northern Lights', strain: 'Indica', thc: 18.5, cbd: 0.3, price: 45.00, cost: 20.00, weight: 3.5,
    desc: 'Classic indica strain known for its relaxing effects and earthy, sweet aroma.' },
  { name: 'Blue Dream', strain: 'Hybrid', thc: 19.2, cbd: 0.5, price: 48.00, cost: 22.00, weight: 3.5,
    desc: 'Popular hybrid combining full-body relaxation with gentle cerebral invigoration.' },
  { name: 'Sour Diesel', strain: 'Sativa', thc: 22.0, cbd: 0.2, price: 52.00, cost: 24.00, weight: 3.5,
    desc: 'Energizing sativa with a pungent diesel-like aroma and dreamy cerebral effects.' },
  { name: 'OG Kush', strain: 'Hybrid', thc: 23.5, cbd: 0.4, price: 55.00, cost: 26.00, weight: 3.5,
    desc: 'Legendary strain with complex aromas of fuel, skunk, and spice.' },
  { name: 'Purple Haze', strain: 'Sativa', thc: 20.0, cbd: 0.3, price: 50.00, cost: 23.00, weight: 3.5,
    desc: 'Uplifting sativa with sweet and earthy flavors and vibrant purple hues.' },
  { name: 'Granddaddy Purple', strain: 'Indica', thc: 21.0, cbd: 0.7, price: 48.00, cost: 22.00, weight: 3.5,
    desc: 'Powerful indica perfect for nighttime use with grape and berry aromas.' },
  { name: 'Girl Scout Cookies', strain: 'Hybrid', thc: 25.0, cbd: 0.5, price: 58.00, cost: 28.00, weight: 3.5,
    desc: 'Sweet and earthy hybrid delivering blissful euphoria and relaxation.' },
  { name: 'Jack Herer', strain: 'Sativa', thc: 18.0, cbd: 0.4, price: 46.00, cost: 21.00, weight: 3.5,
    desc: 'Clear-headed and creative sativa named after the cannabis activist.' },
  { name: 'White Widow', strain: 'Hybrid', thc: 20.5, cbd: 0.3, price: 49.00, cost: 23.00, weight: 3.5,
    desc: 'Balanced hybrid with powerful burst of euphoria and energy.' },
  { name: 'Pineapple Express', strain: 'Hybrid', thc: 19.5, cbd: 0.5, price: 47.00, cost: 22.00, weight: 3.5,
    desc: 'Tropical hybrid delivering long-lasting energetic buzz.' },
  { name: 'Gorilla Glue #4', strain: 'Hybrid', thc: 28.0, cbd: 0.1, price: 62.00, cost: 30.00, weight: 3.5,
    desc: 'Heavy-handed euphoria and relaxation, leaving you feeling "glued" to the couch.' },
  { name: 'Wedding Cake', strain: 'Hybrid', thc: 24.0, cbd: 0.5, price: 56.00, cost: 27.00, weight: 3.5,
    desc: 'Rich and tangy strain with earthy and peppery undertones.' },
  { name: 'Bubba Kush', strain: 'Indica', thc: 17.0, cbd: 0.8, price: 44.00, cost: 20.00, weight: 3.5,
    desc: 'Heavy tranquilizing effects perfect for insomnia and stress relief.' },
  { name: 'Green Crack', strain: 'Sativa', thc: 21.5, cbd: 0.2, price: 51.00, cost: 24.00, weight: 3.5,
    desc: 'Invigorating mental buzz perfect for daytime use.' },
  { name: 'Gelato', strain: 'Hybrid', thc: 22.5, cbd: 0.4, price: 54.00, cost: 26.00, weight: 3.5,
    desc: 'Dessert-like flavor profile with sweet and fruity notes.' },
  { name: 'Zkittlez', strain: 'Indica', thc: 19.0, cbd: 0.6, price: 49.00, cost: 23.00, weight: 3.5,
    desc: 'Calming indica with tropical and berry flavors.' },
  { name: 'Durban Poison', strain: 'Sativa', thc: 20.0, cbd: 0.3, price: 50.00, cost: 23.00, weight: 3.5,
    desc: 'Pure sativa with sweet smell and energetic, uplifting effects.' },
  { name: 'LA Confidential', strain: 'Indica', thc: 19.5, cbd: 0.5, price: 48.00, cost: 22.00, weight: 3.5,
    desc: 'Smooth and piney indica perfect for relaxation and pain relief.' },
  { name: 'Strawberry Cough', strain: 'Sativa', thc: 18.5, cbd: 0.4, price: 47.00, cost: 21.00, weight: 3.5,
    desc: 'Sweet strawberry flavor with uplifting and euphoric effects.' },
  { name: 'AK-47', strain: 'Hybrid', thc: 20.5, cbd: 0.5, price: 49.00, cost: 23.00, weight: 3.5,
    desc: 'Mellow hybrid delivering long-lasting cerebral buzz.' }
]

flower_products.each_with_index do |fp, idx|
  sku = "FL-#{(idx + 1).to_s.rjust(4, '0')}"

  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: fp[:name],
    product_type: :sellable,
    product_status: :active
  )

  # Add attribute values
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:price],
    value: (fp[:price] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cost],
    value: (fp[:cost] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:description],
    value: fp[:desc]
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:short_description],
    value: fp[:desc].split('.').first
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:thc_percentage],
    value: fp[:thc].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cbd_percentage],
    value: fp[:cbd].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:strain_type],
    value: fp[:strain]
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:weight],
    value: fp[:weight].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:package_size],
    value: '3.5g'
  )

  # Terpenes (random selection)
  terpenes = [ 'Myrcene', 'Limonene', 'Caryophyllene', 'Pinene' ].sample(2)
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:terpene_profile],
    value: terpenes.join(',')
  )

  # Add labels
  category_label = case fp[:strain]
  when 'Indica' then labels[:flower_indica]
  when 'Sativa' then labels[:flower_sativa]
  when 'Hybrid' then labels[:flower_hybrid]
  end

  FactoryBot.create(:product_label, product: product, label: labels[:flower])
  FactoryBot.create(:product_label, product: product, label: category_label)
  FactoryBot.create(:product_label, product: product, label: labels[:brand_greenleaf])

  # Add inventory across storages
  storages.each_with_index do |storage, sidx|
    quantity = case storage.code
    when 'MAIN' then rand(100..500)
    when 'RETAIL' then rand(10..50)
    when 'TEMP' then rand(0..20)
    when 'INCOMING' then rand(0..100)
    when 'VAULT' then rand(20..100)
    end

    FactoryBot.create(:inventory,
      product: product,
      storage: storage,
      value: quantity
    )
  end

  # Add to catalogs
  catalogs.each do |catalog|
    price_multiplier = case catalog.currency_code
    when 'eur' then 1.0
    when 'sek' then 10.5
    when 'nok' then 10.2
    end

    catalog_price = (fp[:price] * price_multiplier * 100).to_i

    catalog_item = FactoryBot.create(:catalog_item,
      catalog: catalog,
      product: product,
      catalog_item_state: :active
    )
    catalog_item.write_catalog_attribute_value('price', catalog_price.to_s)
  end

  products << product
end

puts "   ✓ Created #{flower_products.count} flower products"

# -------------------------
# PRE-ROLL PRODUCTS (10)
# -------------------------
puts "\n   Creating Pre-Roll products..."

preroll_products = [
  { name: 'OG Kush Pre-Roll', strain: 'Hybrid', thc: 22.0, cbd: 0.3, price: 12.00, cost: 5.00, weight: 1.0 },
  { name: 'Blue Dream Pre-Roll', strain: 'Hybrid', thc: 18.5, cbd: 0.4, price: 11.00, cost: 4.50, weight: 1.0 },
  { name: 'Sour Diesel Pre-Roll', strain: 'Sativa', thc: 21.0, cbd: 0.2, price: 13.00, cost: 5.50, weight: 1.0 },
  { name: 'Northern Lights Pre-Roll', strain: 'Indica', thc: 17.5, cbd: 0.5, price: 10.00, cost: 4.00, weight: 1.0 },
  { name: 'Wedding Cake Pre-Roll', strain: 'Hybrid', thc: 23.0, cbd: 0.4, price: 14.00, cost: 6.00, weight: 1.0 },
  { name: 'Pre-Roll 5-Pack Mixed', strain: 'Hybrid', thc: 20.0, cbd: 0.3, price: 45.00, cost: 20.00, weight: 5.0 },
  { name: 'Indica Pre-Roll 3-Pack', strain: 'Indica', thc: 19.0, cbd: 0.5, price: 30.00, cost: 13.00, weight: 3.0 },
  { name: 'Sativa Pre-Roll 3-Pack', strain: 'Sativa', thc: 20.5, cbd: 0.2, price: 32.00, cost: 14.00, weight: 3.0 },
  { name: 'CBD Pre-Roll', strain: 'CBD-Dominant', thc: 0.5, cbd: 18.0, price: 10.00, cost: 4.00, weight: 1.0 },
  { name: 'Premium Infused Pre-Roll', strain: 'Hybrid', thc: 35.0, cbd: 0.3, price: 20.00, cost: 9.00, weight: 1.0 }
]

preroll_products.each_with_index do |pr, idx|
  sku = "PR-#{(idx + 1).to_s.rjust(4, '0')}"

  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: pr[:name],
    product_type: :sellable,
    product_status: :active
  )

  # Add attributes (similar pattern as flowers)
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:price],
    value: (pr[:price] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cost],
    value: (pr[:cost] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:description],
    value: "Pre-rolled cannabis ready to enjoy. #{pr[:name]} with #{pr[:thc]}% THC."
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:thc_percentage],
    value: pr[:thc].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cbd_percentage],
    value: pr[:cbd].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:strain_type],
    value: pr[:strain]
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:weight],
    value: pr[:weight].to_s
  )

  # Add labels
  FactoryBot.create(:product_label, product: product, label: labels[:prerolls])
  FactoryBot.create(:product_label, product: product, label: labels[:brand_greenleaf])

  # Add inventory
  storages.each do |storage|
    quantity = case storage.code
    when 'MAIN' then rand(200..800)
    when 'RETAIL' then rand(50..150)
    when 'TEMP' then rand(0..50)
    when 'INCOMING' then rand(0..200)
    when 'VAULT' then rand(50..200)
    end

    FactoryBot.create(:inventory,
      product: product,
      storage: storage,
      value: quantity
    )
  end

  # Add to catalogs
  catalogs.each do |catalog|
    price_multiplier = case catalog.currency_code
    when 'eur' then 1.0
    when 'sek' then 10.5
    when 'nok' then 10.2
    end

    catalog_price = (pr[:price] * price_multiplier * 100).to_i

    catalog_item = FactoryBot.create(:catalog_item,
      catalog: catalog,
      product: product,
      catalog_item_state: :active
    )
    catalog_item.write_catalog_attribute_value('price', catalog_price.to_s)
  end

  products << product
end

puts "   ✓ Created #{preroll_products.count} pre-roll products"

# -------------------------
# EDIBLES PRODUCTS (15)
# -------------------------
puts "\n   Creating Edibles products..."

edibles_products = [
  { name: 'Mixed Berry Gummies 10-Pack', type: :gummies, thc: 10, price: 25.00, cost: 10.00, package: '100mg' },
  { name: 'Watermelon Gummies 20-Pack', type: :gummies, thc: 10, price: 45.00, cost: 18.00, package: '200mg' },
  { name: 'Sour Apple Gummies 5-Pack', type: :gummies, thc: 5, price: 15.00, cost: 6.00, package: '50mg' },
  { name: 'CBD Gummies 30-Pack', type: :gummies, thc: 0, price: 30.00, cost: 12.00, package: '0mg THC' },
  { name: 'Dark Chocolate Bar 100mg', type: :chocolates, thc: 10, price: 20.00, cost: 8.00, package: '100mg' },
  { name: 'Milk Chocolate Bar 200mg', type: :chocolates, thc: 20, price: 35.00, cost: 14.00, package: '200mg' },
  { name: 'White Chocolate Truffles', type: :chocolates, thc: 10, price: 28.00, cost: 11.00, package: '100mg' },
  { name: 'Peanut Butter Cups 4-Pack', type: :chocolates, thc: 10, price: 22.00, cost: 9.00, package: '100mg' },
  { name: 'Chocolate Chip Cookies 4-Pack', type: :baked, thc: 10, price: 24.00, cost: 10.00, package: '100mg' },
  { name: 'Brownie Bites 6-Pack', type: :baked, thc: 10, price: 26.00, cost: 11.00, package: '100mg' },
  { name: 'Snickerdoodle Cookies 4-Pack', type: :baked, thc: 10, price: 24.00, cost: 10.00, package: '100mg' },
  { name: 'Blueberry Muffins 2-Pack', type: :baked, thc: 50, price: 20.00, cost: 8.00, package: '100mg' },
  { name: 'Peach Rings Gummies', type: :gummies, thc: 10, price: 23.00, cost: 9.00, package: '100mg' },
  { name: 'Caramel Chews 10-Pack', type: :chocolates, thc: 5, price: 18.00, cost: 7.00, package: '50mg' },
  { name: 'Fruit Punch Gummies 10-Pack', type: :gummies, thc: 10, price: 25.00, cost: 10.00, package: '100mg' }
]

edibles_products.each_with_index do |ed, idx|
  sku = "ED-#{(idx + 1).to_s.rjust(4, '0')}"

  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: ed[:name],
    product_type: :sellable,
    product_status: :active
  )

  # Add attributes
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:price],
    value: (ed[:price] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cost],
    value: (ed[:cost] * 100).to_i.to_s
  )

  desc = "Delicious cannabis-infused #{ed[:type]}. Each package contains #{ed[:package]} total THC."
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:description],
    value: desc
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:thc_percentage],
    value: ed[:thc].to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:package_size],
    value: ed[:package]
  )

  # Add labels
  category_label = case ed[:type]
  when :gummies then labels[:edibles_gummies]
  when :chocolates then labels[:edibles_chocolates]
  when :baked then labels[:edibles_baked]
  end

  FactoryBot.create(:product_label, product: product, label: labels[:edibles])
  FactoryBot.create(:product_label, product: product, label: category_label)
  FactoryBot.create(:product_label, product: product, label: labels[:brand_pure])

  # Add inventory
  storages.each do |storage|
    quantity = case storage.code
    when 'MAIN' then rand(150..600)
    when 'RETAIL' then rand(30..100)
    when 'TEMP' then rand(0..30)
    when 'INCOMING' then rand(0..150)
    when 'VAULT' then rand(30..150)
    end

    FactoryBot.create(:inventory,
      product: product,
      storage: storage,
      value: quantity
    )
  end

  # Add to catalogs
  catalogs.each do |catalog|
    price_multiplier = case catalog.currency_code
    when 'eur' then 1.0
    when 'sek' then 10.5
    when 'nok' then 10.2
    end

    catalog_price = (ed[:price] * price_multiplier * 100).to_i

    catalog_item = FactoryBot.create(:catalog_item,
      catalog: catalog,
      product: product,
      catalog_item_state: :active
    )
    catalog_item.write_catalog_attribute_value('price', catalog_price.to_s)
  end

  products << product
end

puts "   ✓ Created #{edibles_products.count} edibles products"

# -------------------------
# CONCENTRATES & VAPES (10)
# -------------------------
puts "\n   Creating Concentrates and Vape products..."

concentrate_products = [
  { name: 'Live Resin - Blue Dream 1g', type: :concentrates, thc: 82.5, price: 45.00, cost: 20.00 },
  { name: 'Shatter - OG Kush 1g', type: :concentrates, thc: 85.0, price: 40.00, cost: 18.00 },
  { name: 'Wax - Sour Diesel 1g', type: :concentrates, thc: 80.0, price: 42.00, cost: 19.00 },
  { name: 'Rosin - Wedding Cake 1g', type: :concentrates, thc: 78.0, price: 55.00, cost: 25.00 },
  { name: 'Distillate Syringe 1g', type: :concentrates, thc: 90.0, price: 35.00, cost: 15.00 },
  { name: 'Vape Cartridge - Hybrid 0.5g', type: :vapes, thc: 85.0, price: 38.00, cost: 16.00 },
  { name: 'Vape Cartridge - Indica 0.5g', type: :vapes, thc: 83.0, price: 38.00, cost: 16.00 },
  { name: 'Vape Cartridge - Sativa 0.5g', type: :vapes, thc: 84.0, price: 38.00, cost: 16.00 },
  { name: 'Disposable Vape Pen 0.3g', type: :vapes, thc: 82.0, price: 25.00, cost: 11.00 },
  { name: 'Live Resin Vape Cart 1g', type: :vapes, thc: 88.0, price: 65.00, cost: 28.00 }
]

concentrate_products.each_with_index do |conc, idx|
  sku = "#{conc[:type] == :concentrates ? 'CN' : 'VP'}-#{(idx + 1).to_s.rjust(4, '0')}"

  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: conc[:name],
    product_type: :sellable,
    product_status: :active
  )

  # Add attributes
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:price],
    value: (conc[:price] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cost],
    value: (conc[:cost] * 100).to_i.to_s
  )

  desc = "High-quality #{conc[:type] == :concentrates ? 'concentrate' : 'vaporizer'} with #{conc[:thc]}% THC."
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:description],
    value: desc
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:thc_percentage],
    value: conc[:thc].to_s
  )

  # Add labels
  category_label = conc[:type] == :concentrates ? labels[:concentrates] : labels[:vapes]
  FactoryBot.create(:product_label, product: product, label: category_label)
  FactoryBot.create(:product_label, product: product, label: labels[:brand_greenleaf])

  # Add inventory
  storages.each do |storage|
    quantity = case storage.code
    when 'MAIN' then rand(100..400)
    when 'RETAIL' then rand(20..80)
    when 'TEMP' then rand(0..20)
    when 'INCOMING' then rand(0..100)
    when 'VAULT' then rand(20..100)
    end

    FactoryBot.create(:inventory,
      product: product,
      storage: storage,
      value: quantity
    )
  end

  # Add to catalogs
  catalogs.each do |catalog|
    price_multiplier = case catalog.currency_code
    when 'eur' then 1.0
    when 'sek' then 10.5
    when 'nok' then 10.2
    end

    catalog_price = (conc[:price] * price_multiplier * 100).to_i

    catalog_item = FactoryBot.create(:catalog_item,
      catalog: catalog,
      product: product,
      catalog_item_state: :active
    )
    catalog_item.write_catalog_attribute_value('price', catalog_price.to_s)
  end

  products << product
end

puts "   ✓ Created #{concentrate_products.count} concentrate and vape products"

# -------------------------
# TOPICALS (5)
# -------------------------
puts "\n   Creating Topical products..."

topical_products = [
  { name: 'Pain Relief Balm 100mg', thc: 0, cbd: 100, price: 35.00, cost: 15.00 },
  { name: 'Muscle Rub 200mg', thc: 50, cbd: 150, price: 45.00, cost: 20.00 },
  { name: 'Facial Serum CBD', thc: 0, cbd: 250, price: 55.00, cost: 25.00 },
  { name: 'Massage Oil 500mg', thc: 100, cbd: 400, price: 60.00, cost: 27.00 },
  { name: 'Bath Bombs 4-Pack 100mg', thc: 0, cbd: 100, price: 40.00, cost: 18.00 }
]

topical_products.each_with_index do |top, idx|
  sku = "TP-#{(idx + 1).to_s.rjust(4, '0')}"

  product = FactoryBot.create(:product,
    company: company,
    sku: sku,
    name: top[:name],
    product_type: :sellable,
    product_status: :active
  )

  # Add attributes
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:price],
    value: (top[:price] * 100).to_i.to_s
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cost],
    value: (top[:cost] * 100).to_i.to_s
  )

  desc = "Cannabis-infused topical product. #{top[:thc]}mg THC, #{top[:cbd]}mg CBD. For external use only."
  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:description],
    value: desc
  )

  FactoryBot.create(:product_attribute_value,
    product: product,
    product_attribute: attributes[:cbd_percentage],
    value: (top[:cbd] / 10.0).to_s
  )

  # Add labels
  FactoryBot.create(:product_label, product: product, label: labels[:topicals])
  FactoryBot.create(:product_label, product: product, label: labels[:brand_pure])

  # Add inventory
  storages.each do |storage|
    quantity = case storage.code
    when 'MAIN' then rand(50..200)
    when 'RETAIL' then rand(10..40)
    when 'TEMP' then rand(0..10)
    when 'INCOMING' then rand(0..50)
    when 'VAULT' then rand(10..50)
    end

    FactoryBot.create(:inventory,
      product: product,
      storage: storage,
      value: quantity
    )
  end

  # Add to catalogs
  catalogs.each do |catalog|
    price_multiplier = case catalog.currency_code
    when 'eur' then 1.0
    when 'sek' then 10.5
    when 'nok' then 10.2
    end

    catalog_price = (top[:price] * price_multiplier * 100).to_i

    catalog_item = FactoryBot.create(:catalog_item,
      catalog: catalog,
      product: product,
      catalog_item_state: :active
    )
    catalog_item.write_catalog_attribute_value('price', catalog_price.to_s)
  end

  products << product
end

puts "   ✓ Created #{topical_products.count} topical products"

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + "=" * 80
puts "🎉 Seed process complete!"
puts "=" * 80

puts "\n📊 Summary:"
puts "   Companies: #{Company.count}"
puts "   Storages: #{Storage.count}"
puts "   Catalogs: #{Catalog.count}"
puts "   Product Attributes: #{ProductAttribute.count}"
puts "   Attribute Groups: #{AttributeGroup.count}"
puts "   Labels: #{Label.count}"
puts "   Products: #{Product.count}"
puts "   Product Attribute Values: #{ProductAttributeValue.count}"
puts "   Product Labels: #{ProductLabel.count}"
puts "   Inventories: #{Inventory.count}"
puts "   Catalog Items: #{CatalogItem.count}"

puts "\n📈 Product Breakdown:"
puts "   Flower: 20 products"
puts "   Pre-Rolls: 10 products"
puts "   Edibles: 15 products"
puts "   Concentrates & Vapes: 10 products"
puts "   Topicals: 5 products"
puts "   TOTAL: #{products.count} products"

puts "\n💰 Sample Pricing (EUR):"
sample_products = Product.joins(:product_attribute_values)
  .where(product_attribute_values: { product_attribute_id: attributes[:price].id })
  .limit(5)

sample_products.each do |product|
  price_value = product.product_attribute_values
    .find_by(product_attribute: attributes[:price])
    .value.to_i / 100.0
  puts "   #{product.sku} - #{product.name}: €#{price_value}"
end

puts "\n📦 Sample Inventory:"
sample_storage = storages.first
sample_inventory = Inventory.where(storage: sample_storage).limit(5)
sample_inventory.each do |inv|
  puts "   #{inv.product.sku}: #{inv.value} units in #{sample_storage.name}"
end

puts "\n✨ Ready to use! Access the app at http://localhost:3246"
puts "=" * 80
