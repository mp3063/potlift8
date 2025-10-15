# Variant and Bundle Services Documentation

This document provides comprehensive documentation for the VariantGeneratorService and BundleInventoryCalculator services used in Potlift8's configurable product and bundle system.

## Table of Contents

1. [VariantGeneratorService](#variantgeneratorservice)
2. [BundleInventoryCalculator](#bundleinventorycalculator)
3. [Usage Examples](#usage-examples)
4. [Error Handling](#error-handling)
5. [Integration Points](#integration-points)
6. [Testing](#testing)

---

## VariantGeneratorService

**Location:** `app/services/variant_generator_service.rb`

### Purpose

Generates all possible variant combinations from product configurations. Creates variant products (sellable type) and links them to the configurable parent product via ProductConfiguration relationships.

### How It Works

1. **Validation**: Ensures product is configurable with variant configuration type
2. **Configuration Loading**: Loads all configurations with their values
3. **Cartesian Product**: Generates all possible combinations of configuration values
4. **Variant Creation**: Creates sellable product for each combination
5. **Linking**: Links variant to parent via ProductConfiguration with variant_config metadata

### Key Features

- **Cartesian Product Generation**: Creates all possible combinations automatically
- **Duplicate Prevention**: Skips variants that already exist
- **Unique SKU Generation**: Handles SKU collisions with intelligent numbering
- **Status Inheritance**: Variants inherit parent product status
- **Metadata Storage**: Stores complete configuration details in ProductConfiguration.info
- **Preview Mode**: Preview variants before generating
- **Transaction Safety**: All-or-nothing creation with rollback on errors

### API Reference

#### `initialize(product)`

Creates new service instance.

**Parameters:**
- `product` (Product): Configurable product with variant configuration type

**Example:**
```ruby
service = VariantGeneratorService.new(configurable_product)
```

#### `generate!`

Generates all variant combinations and creates products.

**Returns:** Integer (count of variants created)

**Example:**
```ruby
count = service.generate!
# => 6 (created 6 variants)

service.errors
# => [] (no errors)
```

#### `preview`

Preview variants without creating them.

**Returns:** Array of hashes with variant details

**Example:**
```ruby
variants = service.preview
# => [
#   {
#     sku: "TSHIRT-S-RED",
#     name: "T-Shirt - Small / Red",
#     variant_config: { "size" => "Small", "color" => "Red" },
#     exists: false,
#     status: "new"
#   },
#   ...
# ]
```

#### `valid_for_generation?`

Check if product is ready for variant generation.

**Returns:** Boolean

**Example:**
```ruby
service.valid_for_generation?
# => true (all configurations have values)
```

#### `variant_count`

Count how many variants would be generated.

**Returns:** Integer

**Example:**
```ruby
service.variant_count
# => 6 (3 sizes × 2 colors)
```

### Configuration Details

When linking variants, the service stores comprehensive metadata in `ProductConfiguration.info`:

```ruby
{
  variant_config: {
    "size" => "Small",
    "color" => "Red"
  },
  configuration_details: [
    {
      configuration_id: 123,
      configuration_code: "size",
      configuration_name: "Size",
      value_id: 456,
      value_code: "S",
      value: "Small"
    },
    {
      configuration_id: 124,
      configuration_code: "color",
      configuration_name: "Color",
      value_id: 457,
      value_code: "RED",
      value: "Red"
    }
  ],
  generated_at: "2025-10-15T14:45:00Z",
  generated_by: "VariantGeneratorService"
}
```

### SKU Generation Logic

**Format:** `{PARENT_SKU}-{VALUE1}-{VALUE2}-{VALUE3}`

**Sanitization Rules:**
- Converts to uppercase
- Removes non-alphanumeric characters (except hyphens)
- Replaces spaces with hyphens
- Collapses multiple hyphens
- Removes leading/trailing hyphens

**Collision Handling:**
- Appends incrementing number: `SKU-1`, `SKU-2`, etc.
- Safety limit: 1000 attempts (prevents infinite loops)

**Examples:**
```ruby
# Input: "TSHIRT", ["Small", "Red"]
# Output: "TSHIRT-SMALL-RED"

# Input: "TSHIRT", ["X-Large", "Navy Blue"]
# Output: "TSHIRT-X-LARGE-NAVY-BLUE"

# Collision: "TSHIRT-SMALL-RED" already exists
# Output: "TSHIRT-SMALL-RED-1"
```

### Error Handling

The service collects all errors in the `errors` array:

**Validation Errors:**
- "Product must be configurable type"
- "Product must have variant configuration type"
- "Product must be persisted before generating variants"
- "No configurations found for product"
- "Configuration 'Size' has no values"

**Creation Errors:**
- "Failed to create variant SKU-123: [validation error]"
- "Failed to link variant SKU-123: [validation error]"
- "Transaction failed: [error]"

**Access Errors:**
```ruby
service = VariantGeneratorService.new(product)
count = service.generate!

if count == 0
  puts "Generation failed:"
  service.errors.each { |error| puts "- #{error}" }
end
```

---

## BundleInventoryCalculator

**Location:** `app/services/bundle_inventory_calculator.rb`

### Purpose

Calculates available bundle inventory based on component availability. Determines how many complete bundles can be assembled given current component stock levels.

### How It Works

1. **Component Loading**: Loads all bundle components with inventory data
2. **Limit Calculation**: Calculates max bundles for each component (available / required)
3. **Minimum Selection**: Bundle limit is minimum across all component limits
4. **Bottleneck Identification**: Identifies which component(s) limit bundle assembly

### Key Features

- **Respects Component Quantities**: Handles "2x Stickers" per bundle correctly
- **Bottleneck Detection**: Identifies limiting components
- **Inventory Value**: Calculates total inventory value locked in bundles
- **Zero-Inventory Handling**: Gracefully handles missing/zero inventory
- **Real-Time Calculation**: Uses current inventory levels

### API Reference

#### `initialize(bundle)`

Creates new calculator instance.

**Parameters:**
- `bundle` (Product): Bundle product with components

**Example:**
```ruby
calculator = BundleInventoryCalculator.new(bundle_product)
```

#### `calculate`

Calculate maximum bundles that can be assembled.

**Returns:** Integer (0 if cannot assemble)

**Example:**
```ruby
available = calculator.calculate
# => 5 (can assemble 5 complete bundles)
```

#### `detailed_breakdown`

Get detailed breakdown with bottleneck analysis.

**Returns:** Hash with bundle_limit and component details

**Example:**
```ruby
breakdown = calculator.detailed_breakdown
# => {
#   bundle_sku: "WELCOME-KIT",
#   bundle_name: "Welcome Kit",
#   bundle_limit: 5,
#   can_assemble: true,
#   components: [
#     {
#       sku: "TSHIRT",
#       name: "T-Shirt",
#       required_quantity: 1,
#       available_inventory: 100,
#       bundle_limit: 100,
#       is_bottleneck: false,
#       units_needed_for_bundles: 5,
#       units_remaining: 95
#     },
#     {
#       sku: "STICKER",
#       name: "Sticker",
#       required_quantity: 2,
#       available_inventory: 10,
#       bundle_limit: 5,
#       is_bottleneck: true,  # <-- BOTTLENECK!
#       units_needed_for_bundles: 10,
#       units_remaining: 0
#     }
#   ],
#   bottleneck_components: [
#     { sku: "STICKER", name: "Sticker", ... }
#   ]
# }
```

#### `can_assemble?`

Check if at least one bundle can be assembled.

**Returns:** Boolean

**Example:**
```ruby
calculator.can_assemble?
# => true (has sufficient inventory)
```

#### `inventory_value`

Calculate total inventory value locked in bundles.

**Returns:** Hash with total_value and component breakdown

**Example:**
```ruby
value = calculator.inventory_value
# => {
#   bundle_limit: 5,
#   total_value: 125.50,
#   components: [
#     {
#       sku: "TSHIRT",
#       name: "T-Shirt",
#       required_quantity: 1,
#       available_inventory: 100,
#       units_in_bundles: 5,
#       value_per_unit: 20.00,
#       total_value: 100.00
#     },
#     {
#       sku: "STICKER",
#       name: "Sticker",
#       required_quantity: 2,
#       available_inventory: 10,
#       units_in_bundles: 10,
#       value_per_unit: 2.55,
#       total_value: 25.50
#     }
#   ]
# }
```

#### `bottleneck_component`

Find which component is the bottleneck.

**Returns:** Hash with component details or nil

**Example:**
```ruby
bottleneck = calculator.bottleneck_component
# => {
#   sku: "STICKER",
#   name: "Sticker",
#   required_quantity: 2,
#   available_inventory: 10,
#   bundle_limit: 5
# }
```

### Calculation Logic

**Formula:** `bundle_limit = min(available[i] / required[i]) for all components`

**Example:**

Bundle "Welcome Kit":
- 1× T-Shirt (available: 100)
  - Limit: 100 / 1 = 100 bundles
- 2× Stickers (available: 10)
  - Limit: 10 / 2 = 5 bundles ← **BOTTLENECK**
- 1× Bag (available: 50)
  - Limit: 50 / 1 = 50 bundles

**Result:** Bundle limit = min(100, 5, 50) = **5 bundles**

### Integration with InventoryCalculator

The BundleInventoryCalculator complements the InventoryCalculator concern:

**InventoryCalculator (Model Concern):**
- `total_saldo` - Sum of all inventory across storages
- `total_max_sellable_saldo` - Max sellable inventory (respects storage types)
- Embedded in Product model for direct access

**BundleInventoryCalculator (Service):**
- Uses `total_max_sellable_saldo` from components
- Calculates bundle-level availability
- Provides detailed breakdown and bottleneck analysis
- Separate service for complex calculations

**Usage Together:**
```ruby
# Component inventory (from InventoryCalculator)
component.total_max_sellable_saldo
# => 100

# Bundle inventory (from BundleInventoryCalculator)
calculator = BundleInventoryCalculator.new(bundle)
calculator.calculate
# => 5
```

---

## Usage Examples

### Example 1: Generate T-Shirt Variants

```ruby
# Setup: Configurable T-Shirt product with 2 configurations
company = Company.find_by(code: 'ACME')
tshirt = company.products.create!(
  product_type: :configurable,
  configuration_type: :variant,
  sku: 'TSHIRT-001',
  name: 'Premium T-Shirt'
)

# Create Size configuration
size_config = tshirt.configurations.create!(
  code: 'size',
  name: 'Size',
  position: 1
)
['Small', 'Medium', 'Large'].each_with_index do |size, idx|
  size_config.configuration_values.create!(
    code: size.first,
    value: size,
    position: idx
  )
end

# Create Color configuration
color_config = tshirt.configurations.create!(
  code: 'color',
  name: 'Color',
  position: 2
)
['Red', 'Blue'].each_with_index do |color, idx|
  color_config.configuration_values.create!(
    code: color[0..2].upcase,
    value: color,
    position: idx
  )
end

# Preview variants before generating
service = VariantGeneratorService.new(tshirt)
puts "Will generate #{service.variant_count} variants"
# => Will generate 6 variants

preview = service.preview
preview.each do |variant|
  puts "#{variant[:sku]}: #{variant[:name]}"
end
# Output:
# TSHIRT-001-S-RED: Premium T-Shirt - Small / Red
# TSHIRT-001-S-BLU: Premium T-Shirt - Small / Blue
# TSHIRT-001-M-RED: Premium T-Shirt - Medium / Red
# TSHIRT-001-M-BLU: Premium T-Shirt - Medium / Blue
# TSHIRT-001-L-RED: Premium T-Shirt - Large / Red
# TSHIRT-001-L-BLU: Premium T-Shirt - Large / Blue

# Generate variants
count = service.generate!
puts "Created #{count} variants"
# => Created 6 variants

# Verify variants
tshirt.subproducts.count
# => 6

# Check variant configuration
variant = tshirt.subproducts.first
config = tshirt.product_configurations_as_super.find_by(subproduct: variant)
config.info['variant_config']
# => { "size" => "Small", "color" => "Red" }
```

### Example 2: Calculate Bundle Inventory

```ruby
# Setup: Welcome Kit bundle with 3 components
company = Company.find_by(code: 'ACME')

# Create component products
tshirt = company.products.create!(
  product_type: :sellable,
  sku: 'TSHIRT',
  name: 'T-Shirt'
)
sticker = company.products.create!(
  product_type: :sellable,
  sku: 'STICKER',
  name: 'Sticker'
)
bag = company.products.create!(
  product_type: :sellable,
  sku: 'BAG',
  name: 'Tote Bag'
)

# Add inventory to components
storage = company.storages.sellable_storages.first
tshirt.inventories.create!(storage: storage, saldo: 100)
sticker.inventories.create!(storage: storage, saldo: 10)
bag.inventories.create!(storage: storage, saldo: 50)

# Create bundle
bundle = company.products.create!(
  product_type: :bundle,
  sku: 'WELCOME-KIT',
  name: 'Welcome Kit'
)

# Add components to bundle
bundle.product_configurations_as_super.create!(
  subproduct: tshirt,
  quantity: 1
)
bundle.product_configurations_as_super.create!(
  subproduct: sticker,
  quantity: 2  # Requires 2 stickers per bundle
)
bundle.product_configurations_as_super.create!(
  subproduct: bag,
  quantity: 1
)

# Calculate available bundles
calculator = BundleInventoryCalculator.new(bundle)

# Check if can assemble
calculator.can_assemble?
# => true

# Get bundle limit
calculator.calculate
# => 5 (limited by stickers: 10 / 2 = 5)

# Detailed breakdown
breakdown = calculator.detailed_breakdown
puts "Can assemble #{breakdown[:bundle_limit]} bundles"
puts "\nComponents:"
breakdown[:components].each do |component|
  status = component[:is_bottleneck] ? " (BOTTLENECK)" : ""
  puts "- #{component[:sku]}: #{component[:available_inventory]} available, " \
       "need #{component[:required_quantity]} per bundle = #{component[:bundle_limit]} bundles max#{status}"
end

# Output:
# Can assemble 5 bundles
#
# Components:
# - TSHIRT: 100 available, need 1 per bundle = 100 bundles max
# - STICKER: 10 available, need 2 per bundle = 5 bundles max (BOTTLENECK)
# - BAG: 50 available, need 1 per bundle = 50 bundles max

# Find bottleneck
bottleneck = calculator.bottleneck_component
puts "Bottleneck: #{bottleneck[:name]} (#{bottleneck[:sku]})"
# => Bottleneck: Sticker (STICKER)

# Calculate inventory value
value = calculator.inventory_value
puts "Total inventory value in bundles: $#{value[:total_value]}"
```

### Example 3: Re-generate Variants After Adding Configuration

```ruby
# Existing T-Shirt with Size and Color configurations (6 variants)
tshirt = Product.find_by(sku: 'TSHIRT-001')
tshirt.subproducts.count
# => 6 (S-Red, S-Blue, M-Red, M-Blue, L-Red, L-Blue)

# Add new Material configuration
material_config = tshirt.configurations.create!(
  code: 'material',
  name: 'Material',
  position: 3
)
['Cotton', 'Polyester'].each_with_index do |material, idx|
  material_config.configuration_values.create!(
    code: material[0..2].upcase,
    value: material,
    position: idx
  )
end

# Preview new variants
service = VariantGeneratorService.new(tshirt)
service.variant_count
# => 12 (3 sizes × 2 colors × 2 materials)

preview = service.preview
new_variants = preview.select { |v| v[:status] == 'new' }
existing_variants = preview.select { |v| v[:status] == 'existing' }

puts "Existing: #{existing_variants.count}, New: #{new_variants.count}"
# => Existing: 0, New: 12
# Note: All 12 are "new" because variant_config changed
# Old variants had { size, color }
# New variants have { size, color, material }

# To preserve existing variants, you'd need custom logic to:
# 1. Delete old variants
# 2. Generate new 12-combination variants
# OR keep old variants and mark them as discontinued

# For clean slate approach:
tshirt.product_configurations_as_super.destroy_all
tshirt.subproducts.destroy_all

# Regenerate all variants with new configuration
count = service.generate!
# => 12

tshirt.subproducts.count
# => 12
```

### Example 4: Validate Before Activation

```ruby
# Before activating a bundle, check if it can be assembled
bundle = Product.find_by(sku: 'WELCOME-KIT')

if bundle.product_status_draft?
  calculator = BundleInventoryCalculator.new(bundle)

  if calculator.can_assemble?
    bundle.activate!
    puts "Bundle activated - #{calculator.calculate} bundles available"
  else
    puts "Cannot activate bundle - insufficient component inventory"
    puts "Bottleneck: #{calculator.bottleneck_component[:name]}"
  end
end
```

### Example 5: Admin Action to Generate Variants

```ruby
# In ActiveAdmin resource for products
action_item :generate_variants, only: :show, if: -> {
  resource.product_type_configurable? &&
  resource.configuration_type_variant?
} do
  link_to 'Generate Variants', generate_variants_admin_product_path(resource),
          method: :post,
          data: { confirm: 'Generate all variant combinations?' }
end

member_action :generate_variants, method: :post do
  service = VariantGeneratorService.new(resource)

  count = service.generate!

  if count > 0
    redirect_to admin_product_path(resource),
                notice: "Successfully generated #{count} variants"
  else
    redirect_to admin_product_path(resource),
                alert: "Failed to generate variants: #{service.errors.join(', ')}"
  end
end
```

---

## Error Handling

### VariantGeneratorService Errors

**Validation Errors (before generation):**
```ruby
service = VariantGeneratorService.new(non_configurable_product)
count = service.generate!
# => 0

service.errors
# => ["Product must be configurable type"]
```

**Configuration Errors:**
```ruby
service = VariantGeneratorService.new(product_without_configs)
count = service.generate!
# => 0

service.errors
# => ["No configurations found for product"]
```

**Creation Errors (during generation):**
```ruby
service = VariantGeneratorService.new(product)
count = service.generate!
# => 3 (created 3 before failure)

service.errors
# => ["Failed to create variant TSHIRT-L-RED: SKU has already been taken"]
```

**Safe Error Handling Pattern:**
```ruby
service = VariantGeneratorService.new(product)

if service.valid_for_generation?
  count = service.generate!

  if count > 0
    puts "Success: Generated #{count} variants"
  else
    puts "Failed: #{service.errors.join(', ')}"
  end
else
  puts "Invalid: #{service.errors.join(', ')}"
end
```

### BundleInventoryCalculator Errors

The calculator is designed to be error-tolerant and returns safe defaults:

**Missing Components:**
```ruby
calculator = BundleInventoryCalculator.new(bundle_without_components)
calculator.calculate
# => 0 (safe default)

calculator.can_assemble?
# => false
```

**Invalid Quantities:**
```ruby
# Component with quantity = 0 or nil
calculator = BundleInventoryCalculator.new(bundle)
calculator.calculate
# => 0

# Rails log:
# WARN Invalid quantity for component STICKER: 0
```

**Zero Inventory:**
```ruby
# Component with no inventory records
calculator = BundleInventoryCalculator.new(bundle)
calculator.calculate
# => 0

breakdown = calculator.detailed_breakdown
breakdown[:components].first[:available_inventory]
# => 0
```

---

## Integration Points

### Controller Integration

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  def generate_variants
    @product = current_potlift_company.products.find(params[:id])

    service = VariantGeneratorService.new(@product)

    respond_to do |format|
      if service.valid_for_generation?
        count = service.generate!

        if count > 0
          format.html { redirect_to @product, notice: "Generated #{count} variants" }
          format.json { render json: { count: count, variants: @product.subproducts }, status: :created }
        else
          format.html { redirect_to @product, alert: service.errors.join(', ') }
          format.json { render json: { errors: service.errors }, status: :unprocessable_entity }
        end
      else
        format.html { redirect_to @product, alert: service.errors.join(', ') }
        format.json { render json: { errors: service.errors }, status: :unprocessable_entity }
      end
    end
  end

  def bundle_availability
    @product = current_potlift_company.products.find(params[:id])

    calculator = BundleInventoryCalculator.new(@product)
    breakdown = calculator.detailed_breakdown

    respond_to do |format|
      format.html { render :bundle_availability }
      format.json { render json: breakdown }
    end
  end
end
```

### Background Job Integration

```ruby
# app/jobs/variant_generation_job.rb
class VariantGenerationJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)
    service = VariantGeneratorService.new(product)

    count = service.generate!

    if count > 0
      Rails.logger.info("Generated #{count} variants for product #{product.sku}")
      # Optionally notify admin
      AdminMailer.variant_generation_complete(product, count).deliver_later
    else
      Rails.logger.error("Failed to generate variants: #{service.errors.join(', ')}")
      # Optionally notify admin of failure
      AdminMailer.variant_generation_failed(product, service.errors).deliver_later
    end
  end
end

# Enqueue job
VariantGenerationJob.perform_later(product.id)
```

### Model Integration

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  # ... existing code ...

  # Instance method for convenient variant generation
  def generate_variants!
    service = VariantGeneratorService.new(self)
    service.generate!
  end

  # Check if variants can be generated
  def ready_for_variant_generation?
    service = VariantGeneratorService.new(self)
    service.valid_for_generation?
  end

  # Get bundle availability
  def bundle_availability
    return nil unless product_type_bundle?

    calculator = BundleInventoryCalculator.new(self)
    calculator.calculate
  end

  # Get bundle breakdown
  def bundle_breakdown
    return nil unless product_type_bundle?

    calculator = BundleInventoryCalculator.new(self)
    calculator.detailed_breakdown
  end
end
```

### View Integration

```erb
<!-- app/views/products/show.html.erb -->
<% if @product.product_type_configurable? && @product.configuration_type_variant? %>
  <div class="variant-generation">
    <h3>Variant Generation</h3>

    <% service = VariantGeneratorService.new(@product) %>
    <% if service.valid_for_generation? %>
      <p>
        This product can generate <strong><%= service.variant_count %></strong> variants.
      </p>

      <%= button_to 'Generate Variants',
                    generate_variants_product_path(@product),
                    class: 'btn btn-primary',
                    data: { confirm: "Generate #{service.variant_count} variants?" } %>

      <!-- Preview Table -->
      <table class="variant-preview">
        <thead>
          <tr>
            <th>SKU</th>
            <th>Name</th>
            <th>Configuration</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <% service.preview.first(10).each do |variant| %>
            <tr>
              <td><%= variant[:sku] %></td>
              <td><%= variant[:name] %></td>
              <td><%= variant[:variant_config].to_json %></td>
              <td>
                <%= variant[:exists] ?
                    content_tag(:span, 'Exists', class: 'badge badge-secondary') :
                    content_tag(:span, 'New', class: 'badge badge-success') %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <div class="alert alert-warning">
        Product is not ready for variant generation:
        <ul>
          <% service.errors.each do |error| %>
            <li><%= error %></li>
          <% end %>
        </ul>
      </div>
    <% end %>
  </div>
<% end %>

<% if @product.product_type_bundle? %>
  <div class="bundle-availability">
    <h3>Bundle Availability</h3>

    <% calculator = BundleInventoryCalculator.new(@product) %>
    <% breakdown = calculator.detailed_breakdown %>

    <p>
      Can assemble <strong><%= breakdown[:bundle_limit] %></strong> bundles
    </p>

    <table class="component-breakdown">
      <thead>
        <tr>
          <th>Component</th>
          <th>Required</th>
          <th>Available</th>
          <th>Bundle Limit</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <% breakdown[:components].each do |component| %>
          <tr class="<%= 'bottleneck' if component[:is_bottleneck] %>">
            <td><%= component[:name] %></td>
            <td><%= component[:required_quantity] %></td>
            <td><%= component[:available_inventory] %></td>
            <td><%= component[:bundle_limit] %></td>
            <td>
              <%= component[:is_bottleneck] ?
                  content_tag(:span, 'Bottleneck', class: 'badge badge-warning') :
                  content_tag(:span, 'OK', class: 'badge badge-success') %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

---

## Testing

### RSpec Test Examples

**VariantGeneratorService Spec:**

```ruby
# spec/services/variant_generator_service_spec.rb
require 'rails_helper'

RSpec.describe VariantGeneratorService do
  let(:company) { create(:company) }
  let(:product) { create(:product, :configurable_variant, company: company) }
  let(:service) { described_class.new(product) }

  describe '#generate!' do
    context 'with valid configurations' do
      before do
        # Create Size configuration
        size_config = product.configurations.create!(
          code: 'size',
          name: 'Size',
          position: 1
        )
        ['S', 'M', 'L'].each_with_index do |size, idx|
          size_config.configuration_values.create!(
            code: size,
            value: size,
            position: idx
          )
        end

        # Create Color configuration
        color_config = product.configurations.create!(
          code: 'color',
          name: 'Color',
          position: 2
        )
        ['Red', 'Blue'].each_with_index do |color, idx|
          color_config.configuration_values.create!(
            code: color,
            value: color,
            position: idx
          )
        end
      end

      it 'generates all variant combinations' do
        expect { service.generate! }.to change { product.subproducts.count }.from(0).to(6)
      end

      it 'creates variants with correct SKU format' do
        service.generate!
        skus = product.subproducts.pluck(:sku).sort
        expect(skus).to include("#{product.sku}-S-RED", "#{product.sku}-M-BLUE")
      end

      it 'stores variant_config in ProductConfiguration.info' do
        service.generate!
        config = product.product_configurations_as_super.first
        expect(config.info['variant_config']).to be_present
        expect(config.info['variant_config']).to have_key('size')
        expect(config.info['variant_config']).to have_key('color')
      end

      it 'inherits parent product status' do
        product.update!(product_status: :active)
        service.generate!
        expect(product.subproducts.pluck(:product_status).uniq).to eq(['active'])
      end
    end

    context 'with duplicate variants' do
      before do
        config = product.configurations.create!(code: 'size', name: 'Size', position: 1)
        config.configuration_values.create!(code: 'S', value: 'S', position: 0)
      end

      it 'skips existing variants' do
        service.generate!  # First generation
        expect { service.generate! }.not_to change { product.subproducts.count }
      end
    end

    context 'with invalid product' do
      let(:product) { create(:product, :sellable, company: company) }

      it 'returns 0 and adds errors' do
        count = service.generate!
        expect(count).to eq(0)
        expect(service.errors).to include('Product must be configurable type')
      end
    end
  end

  describe '#preview' do
    before do
      config = product.configurations.create!(code: 'size', name: 'Size', position: 1)
      ['S', 'M'].each_with_index do |size, idx|
        config.configuration_values.create!(code: size, value: size, position: idx)
      end
    end

    it 'returns preview without creating variants' do
      preview = service.preview
      expect(preview).to be_an(Array)
      expect(preview.size).to eq(2)
      expect(product.subproducts.count).to eq(0)  # No variants created
    end

    it 'includes SKU, name, and variant_config' do
      preview = service.preview
      variant = preview.first
      expect(variant).to have_key(:sku)
      expect(variant).to have_key(:name)
      expect(variant).to have_key(:variant_config)
      expect(variant).to have_key(:exists)
    end
  end

  describe '#variant_count' do
    it 'returns correct count for multiple configurations' do
      # 3 sizes × 2 colors = 6 variants
      size_config = product.configurations.create!(code: 'size', name: 'Size', position: 1)
      ['S', 'M', 'L'].each_with_index do |size, idx|
        size_config.configuration_values.create!(code: size, value: size, position: idx)
      end

      color_config = product.configurations.create!(code: 'color', name: 'Color', position: 2)
      ['Red', 'Blue'].each_with_index do |color, idx|
        color_config.configuration_values.create!(code: color, value: color, position: idx)
      end

      expect(service.variant_count).to eq(6)
    end
  end
end
```

**BundleInventoryCalculator Spec:**

```ruby
# spec/services/bundle_inventory_calculator_spec.rb
require 'rails_helper'

RSpec.describe BundleInventoryCalculator do
  let(:company) { create(:company) }
  let(:storage) { create(:storage, :sellable, company: company) }
  let(:bundle) { create(:product, :bundle, company: company) }

  let!(:component1) do
    create(:product, :sellable, company: company).tap do |p|
      create(:inventory, product: p, storage: storage, saldo: 100)
    end
  end

  let!(:component2) do
    create(:product, :sellable, company: company).tap do |p|
      create(:inventory, product: p, storage: storage, saldo: 10)
    end
  end

  before do
    bundle.product_configurations_as_super.create!(
      subproduct: component1,
      quantity: 1
    )
    bundle.product_configurations_as_super.create!(
      subproduct: component2,
      quantity: 2  # Requires 2 per bundle
    )
  end

  let(:calculator) { described_class.new(bundle) }

  describe '#calculate' do
    it 'returns minimum bundle limit across components' do
      # component1: 100 / 1 = 100 bundles
      # component2: 10 / 2 = 5 bundles (bottleneck)
      expect(calculator.calculate).to eq(5)
    end

    context 'with zero inventory' do
      before do
        component2.inventories.destroy_all
      end

      it 'returns 0' do
        expect(calculator.calculate).to eq(0)
      end
    end
  end

  describe '#detailed_breakdown' do
    it 'includes bundle limit and components' do
      breakdown = calculator.detailed_breakdown
      expect(breakdown[:bundle_limit]).to eq(5)
      expect(breakdown[:components].size).to eq(2)
    end

    it 'identifies bottleneck components' do
      breakdown = calculator.detailed_breakdown
      bottleneck = breakdown[:components].find { |c| c[:is_bottleneck] }
      expect(bottleneck[:sku]).to eq(component2.sku)
      expect(breakdown[:bottleneck_components].size).to eq(1)
    end
  end

  describe '#can_assemble?' do
    it 'returns true when inventory available' do
      expect(calculator.can_assemble?).to be true
    end

    it 'returns false when inventory insufficient' do
      component1.inventories.destroy_all
      expect(calculator.can_assemble?).to be false
    end
  end

  describe '#bottleneck_component' do
    it 'returns the limiting component' do
      bottleneck = calculator.bottleneck_component
      expect(bottleneck[:sku]).to eq(component2.sku)
      expect(bottleneck[:bundle_limit]).to eq(5)
    end
  end
end
```

### Test Factories

```ruby
# spec/factories/products.rb
FactoryBot.define do
  factory :product do
    company
    sequence(:sku) { |n| "SKU#{n}" }
    sequence(:name) { |n| "Product #{n}" }
    product_type { :sellable }
    product_status { :draft }

    trait :configurable_variant do
      product_type { :configurable }
      configuration_type { :variant }
    end

    trait :configurable_option do
      product_type { :configurable }
      configuration_type { :option }
    end

    trait :bundle do
      product_type { :bundle }
    end

    trait :sellable do
      product_type { :sellable }
    end

    trait :active do
      product_status { :active }
    end
  end
end

# spec/factories/configurations.rb
FactoryBot.define do
  factory :configuration do
    product
    sequence(:code) { |n| "config_#{n}" }
    sequence(:name) { |n| "Configuration #{n}" }
    position { 0 }
  end
end

# spec/factories/configuration_values.rb
FactoryBot.define do
  factory :configuration_value do
    configuration
    sequence(:code) { |n| "value_#{n}" }
    sequence(:value) { |n| "Value #{n}" }
    position { 0 }
  end
end
```

---

## Performance Considerations

### VariantGeneratorService

**Cartesian Product Complexity:**
- **Formula:** `variants = n1 × n2 × n3 × ... × nN`
- **Example:** 5 sizes × 3 colors × 2 materials = 30 variants
- **Caution:** Exponential growth! 10 × 10 × 10 = 1000 variants

**Database Operations:**
- Creates N variant products (INSERT)
- Creates N product_configurations (INSERT)
- All wrapped in single transaction for atomicity
- Batch size: No artificial batching (relies on transaction)

**Optimization Tips:**
```ruby
# For very large variant counts (>500), consider batching:
def generate_in_batches!(batch_size: 100)
  combinations = generate_combinations(load_configurations)

  combinations.each_slice(batch_size) do |batch|
    ActiveRecord::Base.transaction do
      create_variants(batch)
    end
  end
end
```

**Memory Usage:**
- Loads all combinations into memory before creating
- For 1000 variants: ~100KB memory (negligible)
- For 10,000 variants: ~1MB memory (acceptable)

### BundleInventoryCalculator

**Query Optimization:**
- Uses `includes(:inventories)` for eager loading
- Single query per component (N+1 avoided)
- No database writes (read-only)

**Caching Recommendation:**
```ruby
# Cache bundle availability in Product.cache JSONB field
def cached_bundle_availability
  if cache['bundle_availability_expires_at']&.> Time.current
    return cache['bundle_availability']
  end

  calculator = BundleInventoryCalculator.new(self)
  availability = calculator.calculate

  update_column(:cache, cache.merge(
    'bundle_availability' => availability,
    'bundle_availability_expires_at' => 5.minutes.from_now
  ))

  availability
end
```

---

## Summary

These services provide robust, production-ready functionality for:

1. **VariantGeneratorService:**
   - Automatic variant generation from configurations
   - Cartesian product calculation
   - Duplicate prevention and SKU collision handling
   - Transaction safety with rollback
   - Preview mode for testing

2. **BundleInventoryCalculator:**
   - Real-time bundle availability calculation
   - Bottleneck identification
   - Inventory value calculation
   - Integration with InventoryCalculator concern

Both services follow Rails best practices with comprehensive error handling, logging, and testability.
