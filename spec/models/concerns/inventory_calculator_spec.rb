require 'rails_helper'

RSpec.describe InventoryCalculator, type: :model do
  let(:company) do
    Company.create!(
      code: 'TEST',
      name: 'Test Company',
      active: true
    )
  end

  let(:main_warehouse) do
    Storage.create!(
      company: company,
      code: 'MAIN',
      name: 'Main Warehouse',
      storage_type: :regular,
      storage_status: :active,
      default: true
    )
  end

  let(:secondary_warehouse) do
    Storage.create!(
      company: company,
      code: 'SECONDARY',
      name: 'Secondary Warehouse',
      storage_type: :regular,
      storage_status: :active
    )
  end

  let(:incoming_warehouse) do
    Storage.create!(
      company: company,
      code: 'INCOMING',
      name: 'Incoming Storage',
      storage_type: :incoming,
      storage_status: :active
    )
  end

  let(:deleted_warehouse) do
    Storage.create!(
      company: company,
      code: 'DELETED',
      name: 'Deleted Warehouse',
      storage_type: :regular,
      storage_status: :deleted
    )
  end

  let(:sellable_product) do
    Product.create!(
      company: company,
      sku: 'SELLABLE-001',
      name: 'Sellable Product',
      product_type: :sellable,
      product_status: :active
    )
  end

  describe '#total_saldo' do
    it 'calculates sum across all active warehouses' do
      Inventory.create!(product: sellable_product, storage: main_warehouse, value: 50)
      Inventory.create!(product: sellable_product, storage: secondary_warehouse, value: 75)

      expect(sellable_product.total_saldo).to eq(125)
    end

    it 'excludes deleted warehouses' do
      Inventory.create!(product: sellable_product, storage: main_warehouse, value: 50)
      Inventory.create!(product: sellable_product, storage: deleted_warehouse, value: 100)

      expect(sellable_product.total_saldo).to eq(50)
    end

    it 'returns 0 when no inventory exists' do
      expect(sellable_product.total_saldo).to eq(0)
    end

    it 'includes incoming warehouse inventory' do
      Inventory.create!(product: sellable_product, storage: main_warehouse, value: 50)
      Inventory.create!(product: sellable_product, storage: incoming_warehouse, value: 100)

      expect(sellable_product.total_saldo).to eq(150)
    end
  end

  describe '#total_max_sellable_saldo - Sellable Products' do
    it 'returns total_saldo for sellable product' do
      Inventory.create!(product: sellable_product, storage: main_warehouse, value: 50)
      Inventory.create!(product: sellable_product, storage: secondary_warehouse, value: 30)

      expect(sellable_product.total_max_sellable_saldo).to eq(80)
    end
  end

  describe '#total_max_sellable_saldo - Configurable Products' do
    it 'returns max of variants for configurable product' do
      # Create configurable product
      configurable = Product.create!(
        company: company,
        sku: 'TSHIRT-CONFIG',
        name: 'T-Shirt',
        product_type: :configurable,
        configuration_type: :variant,
        product_status: :active
      )

      # Create variants
      variant_small = Product.create!(
        company: company,
        sku: 'TSHIRT-S',
        name: 'T-Shirt Small',
        product_type: :sellable,
        product_status: :active
      )

      variant_medium = Product.create!(
        company: company,
        sku: 'TSHIRT-M',
        name: 'T-Shirt Medium',
        product_type: :sellable,
        product_status: :active
      )

      variant_large = Product.create!(
        company: company,
        sku: 'TSHIRT-L',
        name: 'T-Shirt Large',
        product_type: :sellable,
        product_status: :active
      )

      # Link variants to configurable
      ProductConfiguration.create!(superproduct: configurable, subproduct: variant_small)
      ProductConfiguration.create!(superproduct: configurable, subproduct: variant_medium)
      ProductConfiguration.create!(superproduct: configurable, subproduct: variant_large)

      # Set inventory for variants
      Inventory.create!(product: variant_small, storage: main_warehouse, value: 30)
      Inventory.create!(product: variant_medium, storage: main_warehouse, value: 75)  # Max
      Inventory.create!(product: variant_large, storage: main_warehouse, value: 50)

      expect(configurable.total_max_sellable_saldo).to eq(75)
    end

    it 'returns 0 for configurable with no variants' do
      configurable = Product.create!(
        company: company,
        sku: 'EMPTY-CONFIG',
        name: 'Empty Configurable',
        product_type: :configurable,
        configuration_type: :variant,
        product_status: :active
      )

      expect(configurable.total_max_sellable_saldo).to eq(0)
    end
  end

  describe '#total_max_sellable_saldo - Bundle Products' do
    it 'returns limiting factor for bundle' do
      # Create bundle product
      bundle = Product.create!(
        company: company,
        sku: 'GIFT-BUNDLE',
        name: 'Gift Bundle',
        product_type: :bundle,
        product_status: :active
      )

      # Create component products
      candle = Product.create!(
        company: company,
        sku: 'CANDLE-001',
        name: 'Candle',
        product_type: :sellable,
        product_status: :active
      )

      card = Product.create!(
        company: company,
        sku: 'CARD-001',
        name: 'Greeting Card',
        product_type: :sellable,
        product_status: :active
      )

      ribbon = Product.create!(
        company: company,
        sku: 'RIBBON-001',
        name: 'Ribbon',
        product_type: :sellable,
        product_status: :active
      )

      # Link components to bundle with quantities
      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: candle,
        info: { 'quantity' => 2 }
      )

      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: card,
        info: { 'quantity' => 1 }
      )

      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: ribbon,
        info: { 'quantity' => 3 }
      )

      # Set inventory
      # Candle: 100 available / 2 required = 50 bundles possible
      Inventory.create!(product: candle, storage: main_warehouse, value: 100)

      # Card: 40 available / 1 required = 40 bundles possible (LIMITING FACTOR)
      Inventory.create!(product: card, storage: main_warehouse, value: 40)

      # Ribbon: 150 available / 3 required = 50 bundles possible
      Inventory.create!(product: ribbon, storage: main_warehouse, value: 150)

      expect(bundle.total_max_sellable_saldo).to eq(40)
    end

    it 'returns 0 for bundle with zero quantity component' do
      bundle = Product.create!(
        company: company,
        sku: 'BUNDLE-ZERO',
        name: 'Bundle with Zero',
        product_type: :bundle,
        product_status: :active
      )

      component = Product.create!(
        company: company,
        sku: 'COMPONENT-001',
        name: 'Component',
        product_type: :sellable,
        product_status: :active
      )

      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: component,
        info: { 'quantity' => 2 }
      )

      # No inventory for component
      expect(bundle.total_max_sellable_saldo).to eq(0)
    end

    it 'returns 0 for empty bundle' do
      bundle = Product.create!(
        company: company,
        sku: 'EMPTY-BUNDLE',
        name: 'Empty Bundle',
        product_type: :bundle,
        product_status: :active
      )

      expect(bundle.total_max_sellable_saldo).to eq(0)
    end

    it 'calculates correctly for bundle with configurable component' do
      # Create bundle
      bundle = Product.create!(
        company: company,
        sku: 'BUNDLE-WITH-CONFIG',
        name: 'Bundle with Configurable',
        product_type: :bundle,
        product_status: :active
      )

      # Create configurable component
      configurable = Product.create!(
        company: company,
        sku: 'CONFIG-COMPONENT',
        name: 'Configurable Component',
        product_type: :configurable,
        configuration_type: :variant,
        product_status: :active
      )

      # Create variants
      variant1 = Product.create!(
        company: company,
        sku: 'VARIANT-1',
        name: 'Variant 1',
        product_type: :sellable,
        product_status: :active
      )

      variant2 = Product.create!(
        company: company,
        sku: 'VARIANT-2',
        name: 'Variant 2',
        product_type: :sellable,
        product_status: :active
      )

      ProductConfiguration.create!(superproduct: configurable, subproduct: variant1)
      ProductConfiguration.create!(superproduct: configurable, subproduct: variant2)

      # Link configurable to bundle
      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: configurable,
        info: { 'quantity' => 2 }
      )

      # Set inventory for variants
      Inventory.create!(product: variant1, storage: main_warehouse, value: 60)
      Inventory.create!(product: variant2, storage: main_warehouse, value: 80)  # Max

      # Bundle requires 2 configurables, max available is 80, so 80/2 = 40 bundles
      expect(bundle.total_max_sellable_saldo).to eq(40)
    end
  end

  describe '#single_inventory_with_eta' do
    it 'returns regular inventory and incoming with eta' do
      Inventory.create!(
        product: sellable_product,
        storage: main_warehouse,
        value: 50
      )

      Inventory.create!(
        product: sellable_product,
        storage: incoming_warehouse,
        value: 100,
        eta: Date.new(2025, 11, 15)
      )

      result = sellable_product.single_inventory_with_eta

      expect(result[:available]).to eq(50)
      expect(result[:incoming]).to eq(100)
      expect(result[:eta]).to eq(Date.new(2025, 11, 15))
    end

    it 'returns zero incoming when none exists' do
      Inventory.create!(
        product: sellable_product,
        storage: main_warehouse,
        value: 50
      )

      result = sellable_product.single_inventory_with_eta

      expect(result[:available]).to eq(50)
      expect(result[:incoming]).to eq(0)
      expect(result[:eta]).to be_nil
    end

    it 'orders incoming by earliest eta' do
      Inventory.create!(
        product: sellable_product,
        storage: main_warehouse,
        value: 50
      )

      incoming1 = Storage.create!(
        company: company,
        code: 'INCOMING-1',
        name: 'Incoming 1',
        storage_type: :incoming,
        storage_status: :active
      )

      incoming2 = Storage.create!(
        company: company,
        code: 'INCOMING-2',
        name: 'Incoming 2',
        storage_type: :incoming,
        storage_status: :active
      )

      # Later date
      Inventory.create!(
        product: sellable_product,
        storage: incoming1,
        value: 200,
        eta: Date.new(2025, 12, 1)
      )

      # Earlier date (should be returned)
      Inventory.create!(
        product: sellable_product,
        storage: incoming2,
        value: 100,
        eta: Date.new(2025, 11, 1)
      )

      result = sellable_product.single_inventory_with_eta

      expect(result[:available]).to eq(50)
      expect(result[:incoming]).to eq(100)
      expect(result[:eta]).to eq(Date.new(2025, 11, 1))
    end

    it 'excludes deleted storage' do
      Inventory.create!(
        product: sellable_product,
        storage: deleted_warehouse,
        value: 100
      )

      result = sellable_product.single_inventory_with_eta

      expect(result[:available]).to eq(0)
      expect(result[:incoming]).to eq(0)
      expect(result[:eta]).to be_nil
    end
  end

  describe '#inventory_by_storage' do
    it 'returns value for specific storage' do
      Inventory.create!(product: sellable_product, storage: main_warehouse, value: 50)
      Inventory.create!(product: sellable_product, storage: secondary_warehouse, value: 75)

      expect(sellable_product.inventory_by_storage(main_warehouse)).to eq(50)
      expect(sellable_product.inventory_by_storage(secondary_warehouse)).to eq(75)
    end

    it 'returns 0 when no inventory exists' do
      expect(sellable_product.inventory_by_storage(main_warehouse)).to eq(0)
    end

    it 'works with deleted storage' do
      Inventory.create!(product: sellable_product, storage: deleted_warehouse, value: 100)

      expect(sellable_product.inventory_by_storage(deleted_warehouse)).to eq(100)
    end
  end

  describe 'Edge Cases' do
    it 'prevents bundle with nested bundle components via validation' do
      bundle1 = Product.create!(
        company: company,
        sku: 'BUNDLE-1',
        name: 'Bundle 1',
        product_type: :bundle,
        product_status: :active
      )

      bundle2 = Product.create!(
        company: company,
        sku: 'BUNDLE-2',
        name: 'Bundle 2',
        product_type: :bundle,
        product_status: :active
      )

      # Try to create invalid configuration
      config = ProductConfiguration.new(
        superproduct: bundle1,
        subproduct: bundle2
      )

      expect(config).not_to be_valid
      expect(config.errors[:subproduct]).to include("cannot be a bundle when superproduct is a bundle")
    end

    it 'invalidates configurable product with non-sellable subproduct' do
      configurable = Product.create!(
        company: company,
        sku: 'CONFIG-INVALID',
        name: 'Invalid Configurable',
        product_type: :configurable,
        configuration_type: :variant,
        product_status: :active
      )

      bundle = Product.create!(
        company: company,
        sku: 'BUNDLE-SUB',
        name: 'Bundle as Subproduct',
        product_type: :bundle,
        product_status: :active
      )

      config = ProductConfiguration.new(
        superproduct: configurable,
        subproduct: bundle
      )

      expect(config).not_to be_valid
      expect(config.errors[:subproduct]).to include("must be sellable for configurable superproducts")
    end

    it 'handles multiple warehouses with mixed storage types' do
      # Create multiple storage types
      regular1 = main_warehouse
      regular2 = secondary_warehouse
      incoming = incoming_warehouse
      deleted = deleted_warehouse

      # Add inventory to all
      Inventory.create!(product: sellable_product, storage: regular1, value: 30)
      Inventory.create!(product: sellable_product, storage: regular2, value: 20)
      Inventory.create!(product: sellable_product, storage: incoming, value: 50)
      Inventory.create!(product: sellable_product, storage: deleted, value: 100)

      # total_saldo should include regular + incoming but not deleted
      expect(sellable_product.total_saldo).to eq(100)

      # single_inventory_with_eta should only count regular as available
      result = sellable_product.single_inventory_with_eta
      expect(result[:available]).to eq(50)  # Only regular storages
      expect(result[:incoming]).to eq(50)   # Incoming storage
    end

    it 'handles bundle calculation division correctly' do
      bundle = Product.create!(
        company: company,
        sku: 'PRECISE-BUNDLE',
        name: 'Precise Bundle',
        product_type: :bundle,
        product_status: :active
      )

      component = Product.create!(
        company: company,
        sku: 'COMPONENT',
        name: 'Component',
        product_type: :sellable,
        product_status: :active
      )

      ProductConfiguration.create!(
        superproduct: bundle,
        subproduct: component,
        info: { 'quantity' => 3 }
      )

      # 100 available / 3 required = 33 bundles (integer division)
      Inventory.create!(product: component, storage: main_warehouse, value: 100)

      expect(bundle.total_max_sellable_saldo).to eq(33)
    end
  end
end
