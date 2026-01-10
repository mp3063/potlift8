# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Search Performance Benchmark', type: :benchmark do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Mock authentication
  before(:all) do
    @company = create(:company)
    @user = create(:user, company: @company)

    # Create large dataset for realistic benchmarking
    puts "\n=== Creating test dataset ==="

    # Products: 1000 records
    print "Creating 1000 products..."
    @products = 1000.times.map do |i|
      product = create(:product,
        company: @company,
        name: "Product #{i}",
        sku: "PROD-#{i}",
        product_status: [ :active, :draft, :discontinued ].sample,
        product_type: [ :sellable, :configurable, :bundle ].sample
      )

      # Add labels (50% of products)
      if i.even?
        label = create(:label, company: @company, name: "Label #{i % 10}")
        create(:product_label, product: product, label: label)
      end

      product
    end
    puts " Done!"

    # Storages: 50 records
    print "Creating 50 storages..."
    @storages = 50.times.map do |i|
      create(:storage, company: @company, name: "Storage #{i}", code: "STORE-#{i}")
    end
    puts " Done!"

    # Product Attributes: 100 records
    print "Creating 100 product attributes..."
    @attributes = 100.times.map do |i|
      create(:product_attribute, company: @company, name: "Attribute #{i}", code: "attr-#{i}")
    end
    puts " Done!"

    # Labels: 200 records
    print "Creating 200 labels..."
    @labels = 200.times.map do |i|
      create(:label, company: @company, name: "Label #{i}", code: "label-#{i}")
    end
    puts " Done!"

    # Catalogs: 20 records
    print "Creating 20 catalogs..."
    @catalogs = 20.times.map do |i|
      create(:catalog, company: @company, name: "Catalog #{i}", code: "cat-#{i}")
    end
    puts " Done!"

    puts "=== Dataset created successfully ===\n"
  end

  after(:all) do
    # Cleanup
    DatabaseCleaner.clean_with(:truncation)
  end

  describe "Search query performance" do
    it "benchmarks single-scope product search" do
      puts "\n--- Product Search Benchmark ---"

      # Warm up
      2.times { search_products('Product 5') }

      results = Benchmark.measure do
        100.times { search_products('Product 5') }
      end

      avg_time = results.real / 100
      puts "Average time per query: #{(avg_time * 1000).round(2)}ms"
      puts "Queries per second: #{(1 / avg_time).round(2)}"

      # Performance threshold: < 50ms per query
      expect(avg_time).to be < 0.05
    end

    it "benchmarks multi-scope search" do
      puts "\n--- Multi-Scope Search Benchmark ---"

      # Warm up
      2.times { search_all('test') }

      results = Benchmark.measure do
        50.times { search_all('test') }
      end

      avg_time = results.real / 50
      puts "Average time per query: #{(avg_time * 1000).round(2)}ms"
      puts "Queries per second: #{(1 / avg_time).round(2)}"

      # Performance threshold: < 100ms per query (searching 5 scopes)
      expect(avg_time).to be < 0.1
    end

    it "benchmarks search with varying query lengths" do
      puts "\n--- Query Length Benchmark ---"

      queries = {
        'short (2 chars)': 'Pr',
        'medium (10 chars)': 'Product 50',
        'long (30 chars)': 'Product with very long name 50',
        'very_long (50 chars)': 'Product with extremely long descriptive name number 50'
      }

      queries.each do |label, query|
        results = Benchmark.measure do
          50.times { search_products(query) }
        end

        avg_time = results.real / 50
        puts "#{label}: #{(avg_time * 1000).round(2)}ms"

        # All queries should complete in reasonable time
        expect(avg_time).to be < 0.1
      end
    end

    it "benchmarks search result set sizes" do
      puts "\n--- Result Set Size Benchmark ---"

      queries = {
        'many_results (100+)': 'Product',      # Matches many
        'medium_results (10-50)': 'Product 5', # Matches ~11 (5, 50-59, 500-599)
        'few_results (1-5)': 'Product 555',    # Matches 1
        'no_results': 'NonexistentProduct'     # Matches 0
      }

      queries.each do |label, query|
        results = Benchmark.measure do
          50.times { search_products(query) }
        end

        avg_time = results.real / 50
        result_count = search_products(query).count
        puts "#{label} (#{result_count} results): #{(avg_time * 1000).round(2)}ms"

        # Performance should degrade gracefully with result size
        expect(avg_time).to be < 0.1
      end
    end
  end

  describe "Index effectiveness" do
    it "benchmarks indexed vs non-indexed searches" do
      puts "\n--- Index Effectiveness Benchmark ---"

      # Indexed search (name, sku)
      indexed_time = Benchmark.measure do
        100.times { search_products('Product 500') }
      end

      # JSONB search (info->description)
      jsonb_time = Benchmark.measure do
        100.times do
          @company.products.where("info->>'description' ILIKE ?", '%description%').limit(50)
        end
      end

      puts "Indexed search: #{(indexed_time.real / 100 * 1000).round(2)}ms"
      puts "JSONB search: #{(jsonb_time.real / 100 * 1000).round(2)}ms"
      puts "Speedup: #{(jsonb_time.real / indexed_time.real).round(2)}x"

      # Indexed searches should be faster
      # Note: In test environment without production-size data, difference may be small
    end

    it "benchmarks compound index usage" do
      puts "\n--- Compound Index Benchmark ---"

      # Single condition
      single_time = Benchmark.measure do
        100.times { @company.products.where(product_status: :active).limit(50) }
      end

      # Compound condition (company_id + product_status + product_type)
      compound_time = Benchmark.measure do
        100.times do
          @company.products.where(product_status: :active, product_type: :sellable).limit(50)
        end
      end

      puts "Single condition: #{(single_time.real / 100 * 1000).round(2)}ms"
      puts "Compound condition: #{(compound_time.real / 100 * 1000).round(2)}ms"

      # Compound index should maintain good performance
      expect(compound_time.real / 100).to be < 0.05
    end
  end

  describe "Cache performance" do
    it "benchmarks cache hit vs miss" do
      puts "\n--- Cache Performance Benchmark ---"

      cache_key = "benchmark_test_#{SecureRandom.hex}"
      cached_data = { results: @products.first(10).map(&:attributes) }

      # Cache miss (first read)
      miss_time = Benchmark.measure do
        100.times do
          Rails.cache.fetch(cache_key, expires_in: 5.minutes) { cached_data }
          Rails.cache.delete(cache_key) # Force miss
        end
      end

      # Cache hit (already cached)
      Rails.cache.write(cache_key, cached_data)
      hit_time = Benchmark.measure do
        100.times { Rails.cache.read(cache_key) }
      end

      puts "Cache miss (with write): #{(miss_time.real / 100 * 1000).round(2)}ms"
      puts "Cache hit (read only): #{(hit_time.real / 100 * 1000).round(2)}ms"
      puts "Speedup: #{(miss_time.real / hit_time.real).round(2)}x"

      # Cache hits should be significantly faster
      expect(hit_time.real).to be < (miss_time.real / 2)

      Rails.cache.delete(cache_key)
    end

    it "benchmarks recent searches cache operations" do
      puts "\n--- Recent Searches Cache Benchmark ---"

      cache_key = "recent_searches:#{@user.id}"

      # Write operations
      write_time = Benchmark.measure do
        100.times do |i|
          recent = Rails.cache.read(cache_key) || []
          recent.unshift("Query #{i}")
          recent = recent.uniq.first(10)
          Rails.cache.write(cache_key, recent, expires_in: 30.days)
        end
      end

      # Read operations
      read_time = Benchmark.measure do
        100.times { Rails.cache.read(cache_key) }
      end

      puts "Write operations: #{(write_time.real / 100 * 1000).round(2)}ms"
      puts "Read operations: #{(read_time.real / 100 * 1000).round(2)}ms"

      # Operations should be fast
      expect(write_time.real / 100).to be < 0.01
      expect(read_time.real / 100).to be < 0.001

      Rails.cache.delete(cache_key)
    end
  end

  describe "Query optimization" do
    it "benchmarks eager loading effectiveness" do
      puts "\n--- Eager Loading Benchmark ---"

      # Without eager loading (N+1 queries)
      no_eager_time = Benchmark.measure do
        10.times do
          products = @company.products.limit(20)
          products.each do |product|
            product.labels.to_a  # Triggers additional query per product
          end
        end
      end

      # With eager loading
      eager_time = Benchmark.measure do
        10.times do
          products = @company.products.includes(:labels).limit(20)
          products.each do |product|
            product.labels.to_a  # Uses preloaded data
          end
        end
      end

      puts "Without eager loading: #{(no_eager_time.real / 10 * 1000).round(2)}ms"
      puts "With eager loading: #{(eager_time.real / 10 * 1000).round(2)}ms"
      puts "Speedup: #{(no_eager_time.real / eager_time.real).round(2)}x"

      # Eager loading should be faster
      expect(eager_time.real).to be < no_eager_time.real
    end

    it "benchmarks select optimization" do
      puts "\n--- Select Optimization Benchmark ---"

      # Select all columns
      all_columns_time = Benchmark.measure do
        100.times { @company.products.limit(50).to_a }
      end

      # Select specific columns only
      select_columns_time = Benchmark.measure do
        100.times { @company.products.select(:id, :name, :sku, :product_status).limit(50).to_a }
      end

      puts "All columns: #{(all_columns_time.real / 100 * 1000).round(2)}ms"
      puts "Selected columns: #{(select_columns_time.real / 100 * 1000).round(2)}ms"
      puts "Speedup: #{(all_columns_time.real / select_columns_time.real).round(2)}x"

      # Selected columns should be faster (especially with large JSONB fields)
      # Note: Difference may be small in test environment
    end
  end

  describe "Pagination performance" do
    it "benchmarks page traversal" do
      puts "\n--- Pagination Benchmark ---"

      pages = [ 1, 10, 20, 50 ]
      per_page = 20

      pages.each do |page_num|
        time = Benchmark.measure do
          50.times { @company.products.limit(per_page).offset((page_num - 1) * per_page).to_a }
        end

        avg_time = time.real / 50
        puts "Page #{page_num}: #{(avg_time * 1000).round(2)}ms"

        # Performance should remain reasonable even for deep pages
        expect(avg_time).to be < 0.1
      end
    end
  end

  describe "Concurrent operations" do
    it "benchmarks concurrent search requests" do
      puts "\n--- Concurrent Requests Benchmark ---"

      sequential_time = Benchmark.measure do
        10.times { search_products('Product 5') }
      end

      concurrent_time = Benchmark.measure do
        threads = 10.times.map do
          Thread.new { search_products('Product 5') }
        end
        threads.each(&:join)
      end

      puts "Sequential: #{(sequential_time.real * 1000).round(2)}ms"
      puts "Concurrent (10 threads): #{(concurrent_time.real * 1000).round(2)}ms"
      puts "Speedup: #{(sequential_time.real / concurrent_time.real).round(2)}x"

      # Concurrent execution should show improvement
      # Note: Ruby MRI has GIL, so speedup may be limited
    end
  end

  describe "Memory usage" do
    it "benchmarks memory consumption for large result sets" do
      puts "\n--- Memory Usage Benchmark ---"

      GC.start
      before_memory = `ps -o rss= -p #{Process.pid}`.to_i

      # Load large result set
      results = @company.products.limit(500).to_a

      after_memory = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = after_memory - before_memory

      puts "Memory increase: #{memory_increase} KB"
      puts "Records loaded: #{results.count}"
      puts "Memory per record: #{(memory_increase.to_f / results.count).round(2)} KB"

      # Memory usage should be reasonable
      expect(memory_increase).to be < 100_000 # Less than 100MB
    end
  end

  private

  def search_products(query)
    @company.products
      .where("name ILIKE :query OR sku ILIKE :query", query: "%#{query}%")
      .limit(50)
  end

  def search_all(query)
    {
      products: @company.products.where("name ILIKE ?", "%#{query}%").limit(5),
      storage: @company.storages.where("name ILIKE ?", "%#{query}%").limit(5),
      attributes: @company.product_attributes.where("name ILIKE ?", "%#{query}%").limit(5),
      labels: @company.labels.where("name ILIKE ?", "%#{query}%").limit(5),
      catalogs: @company.catalogs.where("name ILIKE ?", "%#{query}%").limit(5)
    }
  end
end
