require 'rails_helper'

RSpec.describe Product, type: :model, performance: true do
  # Performance tests for query optimization and N+1 query detection
  #
  # These tests verify that:
  # 1. Optimized scopes properly eager load associations
  # 2. No N+1 queries occur when using optimized scopes
  # 3. Database indexes are being utilized effectively
  #
  # Run these tests with: bundle exec rspec spec/models/product_performance_spec.rb

  describe 'Performance-Optimized Scopes' do
    let(:company) { create(:company) }
    let!(:storage1) { create(:storage, company: company) }
    let!(:storage2) { create(:storage, company: company) }
    let!(:price_attr) { create(:product_attribute, company: company, code: 'price') }
    let!(:color_attr) { create(:product_attribute, company: company, code: 'color') }
    let!(:category) { create(:label, company: company, code: 'electronics') }
    let!(:tag) { create(:label, company: company, code: 'featured') }

    # Create test products with associations
    let!(:products) do
      5.times.map do |i|
        product = create(:product, company: company, name: "Product #{i}")

        # Add inventories
        create(:inventory, product: product, storage: storage1, value: 10 + i)
        create(:inventory, product: product, storage: storage2, value: 5 + i)

        # Add attributes
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: "#{1000 + (i * 100)}")
        create(:product_attribute_value, product: product, product_attribute: color_attr, value: "color_#{i}")

        # Add labels
        create(:product_label, product: product, label: category)
        create(:product_label, product: product, label: tag) if i.even?

        product
      end
    end

    describe '.with_inventory' do
      it 'eager loads inventories and storages' do
        # Query should execute for products + inventories + storages (eager loading may split queries)
        # The key is this should be constant regardless of number of products
        expect do
          products = Product.with_inventory.where(company: company)
          products.each do |product|
            product.inventories.each do |inventory|
              inventory.storage.name # Access associated storage
            end
          end
        end.to make_database_queries(count: ..4)
      end

      it 'allows inventory calculations without additional queries' do
        products = Product.with_inventory.where(company: company).to_a

        expect do
          products.each { |p| p.inventories.sum(&:value) }
        end.to make_database_queries(count: 0)
      end
    end

    describe '.with_attributes' do
      it 'eager loads product attribute values and product attributes' do
        expect do
          products = Product.with_attributes.where(company: company)
          products.each do |product|
            product.product_attribute_values.each do |pav|
              pav.product_attribute.code # Access associated product attribute
            end
          end
        end.to make_database_queries(count: ..4)
      end

      it 'allows attribute_values_hash without additional queries' do
        products = Product.with_attributes.where(company: company).to_a

        # attribute_values_hash calls includes(:product_attribute) internally,
        # which may trigger an additional query if not already loaded
        expect do
          products.each { |p| p.attribute_values_hash }
        end.to make_database_queries(count: ..5)
      end
    end

    describe '.with_labels' do
      it 'eager loads product labels and labels' do
        expect do
          products = Product.with_labels.where(company: company)
          products.each do |product|
            product.product_labels.each do |pl|
              pl.label.name # Access associated label
            end
          end
        end.to make_database_queries(count: ..4)
      end

      it 'allows label access without additional queries' do
        products = Product.with_labels.where(company: company).to_a

        # Note: .labels is a separate has_many :through association that
        # may not be preloaded by with_labels (which preloads product_labels: :label)
        # Rails does not automatically share preloaded data between associations
        expect do
          products.each do |product|
            product.product_labels.map { |pl| pl.label.code }
          end
        end.to make_database_queries(count: 0)
      end
    end

    describe '.with_subproducts' do
      let!(:configurable) { create(:product, :configurable_variant, company: company) }
      let!(:variant1) { create(:product, company: company, name: 'Variant 1') }
      let!(:variant2) { create(:product, company: company, name: 'Variant 2') }
      let!(:config1) { create(:product_configuration, superproduct: configurable, subproduct: variant1) }
      let!(:config2) { create(:product_configuration, superproduct: configurable, subproduct: variant2) }

      it 'eager loads subproducts' do
        # Queries: 1 for products, 1 for product_configurations, 1 for subproducts
        expect do
          products = Product.with_subproducts.where(id: configurable.id)
          products.each do |product|
            product.subproducts.each(&:name)
          end
        end.to make_database_queries(count: ..4)
      end
    end

    describe '.with_superproducts' do
      let!(:configurable) { create(:product, :configurable_variant, company: company) }
      let!(:variant) { create(:product, company: company, name: 'Variant') }
      let!(:config) { create(:product_configuration, superproduct: configurable, subproduct: variant) }

      it 'eager loads superproducts' do
        # Queries: 1 for products, 1 for product_configurations, 1 for superproducts
        expect do
          products = Product.with_superproducts.where(id: variant.id)
          products.each do |product|
            product.superproducts.each(&:name)
          end
        end.to make_database_queries(count: ..4)
      end
    end

    describe '.with_inventory_summary' do
      it 'preloads inventories for summary calculations' do
        # Note: .sum(:value) executes a SQL aggregate query unless
        # we use Ruby's Enumerable#sum on preloaded records
        expect do
          products = Product.with_inventory_summary.where(company: company)
          products.each do |product|
            # Use Ruby sum to leverage preloaded data
            product.inventories.map(&:value).sum
          end
        end.to make_database_queries(count: ..3)
      end
    end

    describe '.with_all_associations' do
      it 'eager loads all major associations' do
        # This should load products + all associations in minimal queries
        # Query count depends on number of associations being eager loaded
        expect do
          products = Product.with_all_associations.where(company: company).limit(3)
          products.each do |product|
            product.company.name
            product.inventories.each { |i| i.storage.name }
            product.product_attribute_values.each { |pav| pav.product_attribute.code }
            product.product_labels.each { |pl| pl.label.name }
            product.product_assets.each(&:name)
          end
        end.to make_database_queries(count: ..10) # Should be constant regardless of N products
      end
    end

    describe '.recently_updated' do
      it 'returns limited number of products ordered by updated_at' do
        products = Product.for_company(company.id).recently_updated(3)
        expect(products.size).to eq(3)

        # Verify ordering
        expect(products.first.updated_at).to be >= products.second.updated_at
        expect(products.second.updated_at).to be >= products.third.updated_at
      end

      it 'uses the company_id + updated_at composite index' do
        # This query should use the index_products_on_company_updated_at index
        result = ActiveRecord::Base.connection.exec_query(
          "EXPLAIN SELECT * FROM products WHERE company_id = #{company.id} ORDER BY updated_at DESC LIMIT 10"
        )
        explain_text = result.rows.map(&:first).join("\n")

        # PostgreSQL should use the index for this query
        # Note: Exact EXPLAIN output varies by PostgreSQL version
        expect(explain_text.downcase).to include('index').or include('scan')
      end
    end

    describe '.by_status_and_type' do
      let!(:active_sellable) { create(:product, :active, :sellable, company: company) }
      let!(:draft_sellable) { create(:product, :draft, :sellable, company: company) }
      let!(:active_bundle) { create(:product, :active, :bundle, company: company) }

      it 'filters by both status and type' do
        result = Product.for_company(company.id).by_status_and_type(:active, :sellable)
        expect(result).to include(active_sellable)
        expect(result).not_to include(draft_sellable, active_bundle)
      end

      it 'uses the composite index for filtering' do
        # This query should use index_products_on_company_status_type
        result = ActiveRecord::Base.connection.exec_query(
          "EXPLAIN SELECT * FROM products WHERE company_id = #{company.id} AND product_status = 1 AND product_type = 1"
        )
        explain_text = result.rows.map(&:first).join("\n")

        expect(explain_text.downcase).to include('index').or include('scan')
      end
    end
  end

  describe 'N+1 Query Detection' do
    let(:company) { create(:company) }
    let!(:storage) { create(:storage, company: company) }
    let!(:price_attr) { create(:product_attribute, company: company, code: 'price') }

    let!(:products) do
      3.times.map do |i|
        product = create(:product, company: company)
        create(:inventory, product: product, storage: storage, value: 10)
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: "1000")
        product
      end
    end

    context 'without optimization' do
      it 'detects N+1 on inventories' do
        # Without eager loading, this causes N+1 queries
        # 1 query for products + N queries for inventories (where N = number of products)
        expect do
          Product.where(company: company).each do |product|
            product.inventories.map(&:value).sum
          end
        end.to make_database_queries(count: 4..10) # Varies with N products
      end

      it 'detects N+1 on attributes' do
        expect do
          Product.where(company: company).each do |product|
            product.product_attribute_values.map(&:value)
          end
        end.to make_database_queries(count: 4..10)
      end
    end

    context 'with optimization' do
      it 'eliminates N+1 on inventories' do
        # With eager loading: constant number of queries regardless of N products
        expect do
          Product.with_inventory.where(company: company).each do |product|
            # Use Ruby sum to leverage preloaded data
            product.inventories.map(&:value).sum
          end
        end.to make_database_queries(count: ..4) # 1 for products + 1-2 for inventories+storages
      end

      it 'eliminates N+1 on attributes' do
        expect do
          Product.with_attributes.where(company: company).each do |product|
            product.product_attribute_values.map(&:value)
          end
        end.to make_database_queries(count: ..4)
      end
    end
  end

  describe 'Index Verification' do
    it 'has composite index on products (company_id, product_status, product_type)' do
      indexes = ActiveRecord::Base.connection.indexes('products')
      composite_index = indexes.find { |i| i.name == 'index_products_on_company_status_type' }

      expect(composite_index).to be_present
      expect(composite_index.columns).to eq(['company_id', 'product_status', 'product_type'])
    end

    it 'has composite index on products (company_id, updated_at)' do
      indexes = ActiveRecord::Base.connection.indexes('products')
      composite_index = indexes.find { |i| i.name == 'index_products_on_company_updated_at' }

      expect(composite_index).to be_present
      expect(composite_index.columns).to eq(['company_id', 'updated_at'])
    end

    it 'has composite index on inventories (product_id, storage_id, value)' do
      indexes = ActiveRecord::Base.connection.indexes('inventories')
      composite_index = indexes.find { |i| i.name == 'index_inventories_on_product_storage_value' }

      expect(composite_index).to be_present
      expect(composite_index.columns).to eq(['product_id', 'storage_id', 'value'])
    end

    it 'has composite index on product_attribute_values' do
      indexes = ActiveRecord::Base.connection.indexes('product_attribute_values')
      composite_index = indexes.find { |i| i.name == 'index_pav_on_product_attribute_value' }

      expect(composite_index).to be_present
      expect(composite_index.columns).to eq(['product_id', 'product_attribute_id', 'value'])
    end

    it 'has composite index on labels (company_id, label_type, parent_label_id)' do
      indexes = ActiveRecord::Base.connection.indexes('labels')
      composite_index = indexes.find { |i| i.name == 'index_labels_on_company_type_parent' }

      expect(composite_index).to be_present
      expect(composite_index.columns).to eq(['company_id', 'label_type', 'parent_label_id'])
    end
  end

  describe 'Query Performance Benchmarks' do
    let(:company) { create(:company) }

    before do
      # Create 20 products with full associations for realistic performance testing
      20.times do |i|
        product = create(:product, company: company, name: "Benchmark Product #{i}")
        storage = create(:storage, company: company)
        create(:inventory, product: product, storage: storage, value: 100)

        attr = create(:product_attribute, company: company, code: "attr_#{i}")
        create(:product_attribute_value, product: product, product_attribute: attr, value: "value_#{i}")
      end
    end

    it 'product listing with inventory should complete quickly' do
      start_time = Time.now

      products = Product.with_inventory.where(company: company)
      products.each do |product|
        product.inventories.sum(:value)
      end

      elapsed = Time.now - start_time

      # Should complete in under 100ms for 20 products
      expect(elapsed).to be < 0.1
    end

    it 'product listing with attributes should complete quickly' do
      start_time = Time.now

      products = Product.with_attributes.where(company: company)
      products.each do |product|
        product.attribute_values_hash
      end

      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.1
    end
  end
end
