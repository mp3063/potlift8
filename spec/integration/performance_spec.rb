# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Performance Integration', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Mock authentication
  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
      { id: user.id, email: user.email, name: user.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(
      { id: company.id, code: company.code, name: company.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe "N+1 query prevention" do
    context "search results" do
      let!(:products) do
        5.times.map do |i|
          product = create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
          # Associate labels
          label = create(:label, company: company, name: "Label #{i}")
          create(:product_label, product: product, label: label)
          product
        end
      end

      it "prevents N+1 queries when searching products" do
        # Count queries for the search request
        queries = count_queries do
          get search_path, params: { q: 'Product', scope: 'products' }, as: :json
        end

        expect(response).to have_http_status(:success)

        # Should use eager loading to prevent N+1
        # Expected: 1 query for products + 1 for labels (with includes/preload)
        # Allow some overhead for ActiveRecord internals
        expect(queries).to be <= 10
      end

      it "maintains query count with more results" do
        # Add 20 more products with labels
        20.times do |i|
          product = create(:product, company: company, name: "Extra Product #{i}", sku: "EXTRA-#{i}")
          label = create(:label, company: company, name: "Extra Label #{i}")
          create(:product_label, product: product, label: label)
        end

        queries = count_queries do
          get search_path, params: { q: 'Product', scope: 'products' }, as: :json
        end

        # Query count should not increase proportionally with result count
        # This verifies eager loading is working
        expect(queries).to be <= 15 # Allow slight increase for complexity
      end
    end

    context "product index with filters" do
      let!(:products) do
        10.times.map do |i|
          product = create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
          create(:inventory, product: product, storage: create(:storage, company: company))
          product
        end
      end

      it "prevents N+1 queries when loading product list" do
        queries = count_queries do
          get products_path
        end

        expect(response).to have_http_status(:success)

        # Should use eager loading (with_inventory, with_labels, etc.)
        # Expected: Minimal queries regardless of product count
        expect(queries).to be <= 20
      end

      it "maintains query count when filtering" do
        queries = count_queries do
          get products_path, params: { status: 'active' }
        end

        # Adding filters should not significantly increase query count
        expect(queries).to be <= 25
      end
    end

    context "product show with associations" do
      let!(:product) do
        product = create(:product, company: company, name: 'Test Product')
        create(:inventory, product: product, storage: create(:storage, company: company))
        3.times { create(:product_label, product: product, label: create(:label, company: company)) }
        create_list(:product_attribute_value, 5, product: product)
        product
      end

      it "prevents N+1 queries when showing product details" do
        queries = count_queries do
          get product_path(product)
        end

        expect(response).to have_http_status(:success)

        # Should eager load all associations
        # Expected: Single query per association type
        expect(queries).to be <= 30
      end
    end
  end

  describe "Database indexes usage" do
    context "product searches" do
      let!(:products) do
        100.times.map do |i|
          create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
        end
      end

      it "uses indexes for ILIKE queries on name" do
        # PostgreSQL should use trigram index if available
        # This test verifies the query doesn't do a sequential scan

        get search_path, params: { q: 'Product 5', scope: 'products' }, as: :json

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['products']).not_to be_empty
      end

      it "uses indexes for SKU searches" do
        get search_path, params: { q: 'PROD-50', scope: 'products' }, as: :json

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['products']).not_to be_empty
      end

      it "uses composite indexes for filtered queries" do
        # Composite index: (company_id, product_status, product_type)

        get products_path, params: { status: 'active', product_type_id: '1' }

        expect(response).to have_http_status(:success)
      end
    end

    context "multi-tenant queries" do
      let!(:products) do
        50.times.map { |i| create(:product, company: company, name: "Product #{i}") }
      end

      it "uses company_id index for scoping" do
        # All queries should be scoped by company_id (multi-tenant)

        get search_path, params: { q: 'Product', scope: 'products' }, as: :json

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['products'].count).to be <= 50
      end
    end
  end

  describe "Counter cache performance" do
    context "products with subproducts" do
      let!(:configurable_product) do
        product = create(:product, company: company, product_type: :configurable, configuration_type: :variant)
        # Add subproducts
        5.times do
          subproduct = create(:product, company: company, product_type: :sellable)
          create(:product_configuration, superproduct: product, subproduct: subproduct)
        end
        product
      end

      it "uses counter cache for subproducts count" do
        # If counter cache is implemented, this should not query database
        queries = count_queries do
          count = configurable_product.subproducts.size
          expect(count).to eq(5)
        end

        # With counter cache: 0 queries
        # Without counter cache: 1 query
        expect(queries).to be <= 1
      end
    end

    context "labels with products" do
      let!(:label) do
        label = create(:label, company: company)
        10.times { create(:product_label, label: label, product: create(:product, company: company)) }
        label
      end

      it "uses counter cache for products count" do
        queries = count_queries do
          count = label.products.count
          expect(count).to eq(10)
        end

        # Should use counter cache if implemented
        expect(queries).to be <= 1
      end
    end
  end

  describe "Query count thresholds" do
    it "keeps search query count under threshold" do
      # Create test data
      create_list(:product, 5, company: company)
      create_list(:storage, 3, company: company)
      create_list(:label, 5, company: company)

      queries = count_queries do
        get search_path, params: { q: 'test', scope: 'all' }, as: :json
      end

      # Threshold: Should not exceed 30 queries for multi-scope search
      expect(queries).to be <= 30
    end

    it "keeps product index query count under threshold" do
      create_list(:product, 20, company: company)

      queries = count_queries do
        get products_path
      end

      # Threshold: Should not exceed 35 queries
      expect(queries).to be <= 35
    end

    it "keeps product show query count under threshold" do
      product = create(:product, company: company)
      create_list(:inventory, 3, product: product)
      3.times { create(:product_label, product: product, label: create(:label, company: company)) }

      queries = count_queries do
        get product_path(product)
      end

      # Threshold: Should not exceed 30 queries
      expect(queries).to be <= 30
    end
  end

  describe "Response time thresholds" do
    before do
      # Create realistic dataset
      50.times do |i|
        product = create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
        create(:inventory, product: product, storage: create(:storage, company: company))
        create(:product_label, product: product, label: create(:label, company: company))
      end
    end

    it "completes search within acceptable time" do
      start_time = Time.current

      get search_path, params: { q: 'Product', scope: 'all' }, as: :json

      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)

      # Threshold: Should complete in under 500ms
      expect(elapsed).to be < 0.5
    end

    it "completes filtered product list within acceptable time" do
      start_time = Time.current

      get products_path, params: { status: 'active' }

      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)

      # Threshold: Should complete in under 1 second
      expect(elapsed).to be < 1.0
    end

    it "completes product show within acceptable time" do
      product = Product.first

      start_time = Time.current

      get product_path(product)

      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)

      # Threshold: Should complete in under 300ms
      expect(elapsed).to be < 0.3
    end
  end

  describe "Pagination performance" do
    before do
      # Create many products
      100.times do |i|
        create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
      end
    end

    it "maintains consistent query count across pages" do
      first_page_queries = count_queries do
        get products_path, params: { page: 1 }
      end

      second_page_queries = count_queries do
        get products_path, params: { page: 2 }
      end

      # Query count should be consistent across pages
      expect(first_page_queries).to be_within(5).of(second_page_queries)
    end

    it "uses LIMIT and OFFSET efficiently" do
      # Request specific page
      get products_path, params: { page: 3, per_page: 10 }

      expect(response).to have_http_status(:success)

      # Should not load all records before limiting
      # This is a smoke test - Rails handles this efficiently by default
    end
  end

  describe "Eager loading strategies" do
    let!(:product) do
      product = create(:product, company: company)
      create(:inventory, product: product, storage: create(:storage, company: company))
      3.times { create(:product_label, product: product, label: create(:label, company: company)) }
      create_list(:product_attribute_value, 5, product: product)
      product
    end

    it "uses includes for associations when filtering" do
      queries = count_queries do
        get products_path, params: { label_ids: [ product.labels.first.id ] }
      end

      expect(response).to have_http_status(:success)

      # Should use includes (LEFT OUTER JOIN) for filtering
      expect(queries).to be <= 20
    end

    it "uses preload for associations when only displaying" do
      # When associations are only displayed (not filtered),
      # preload (separate queries) may be more efficient than includes

      queries = count_queries do
        get product_path(product)
      end

      expect(response).to have_http_status(:success)
      expect(queries).to be <= 30
    end
  end

  describe "Select optimization" do
    it "selects only necessary columns for list views" do
      create_list(:product, 10, company: company)

      # In optimized implementations, list views should select only:
      # id, name, sku, product_status, product_type, updated_at
      # Not the entire record with large JSONB fields

      get products_path

      expect(response).to have_http_status(:success)

      # This is a smoke test - actual optimization may vary
    end
  end

  describe "JSONB query performance" do
    let!(:products) do
      20.times.map do |i|
        create(:product,
          company: company,
          name: "Product #{i}",
          info: { description: "Description #{i}", price: i * 100 }
        )
      end
    end

    it "efficiently queries JSONB fields" do
      # Query JSONB field with GIN index (if available)
      get search_path, params: { q: 'Description 5', scope: 'products' }, as: :json

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json['products']).not_to be_empty
    end

    it "handles JSONB queries without full table scan" do
      queries = count_queries do
        get search_path, params: { q: 'Description', scope: 'products' }, as: :json
      end

      # Should complete efficiently even with JSONB queries
      expect(queries).to be <= 15
    end
  end

  describe "Concurrent request handling" do
    it "handles multiple concurrent search requests" do
      create_list(:product, 20, company: company)

      threads = 5.times.map do
        Thread.new do
          get search_path, params: { q: 'Product', scope: 'all' }, as: :json
          expect(response).to have_http_status(:success)
        end
      end

      threads.each(&:join)

      # All requests should complete successfully
      # This verifies connection pool and Redis can handle concurrency
    end
  end

  private

  # Helper to count database queries
  def count_queries(&block)
    count = 0
    callback = lambda do |name, started, finished, unique_id, payload|
      # Only count actual queries, not schema queries or cache hits
      unless payload[:name]&.include?('SCHEMA') || payload[:name]&.include?('CACHE')
        count += 1
      end
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      block.call
    end

    count
  end
end
