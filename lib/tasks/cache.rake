# Cache Management Rake Tasks
#
# Provides tasks for monitoring, warming, and clearing cache.
# Use these tasks for maintenance and performance optimization.
#
# Usage:
#   rake cache:stats              # Display cache statistics
#   rake cache:report             # Generate detailed cache report
#   rake cache:clear              # Clear all cache entries
#   rake cache:warm_products      # Warm product cache
#   rake cache:test               # Test cache performance
#
namespace :cache do
  desc "Display cache statistics"
  task stats: :environment do
    puts "\n"
    puts "=" * 60
    puts "Cache Statistics"
    puts "=" * 60

    monitor = CacheMonitorService.new
    stats = monitor.cache_stats

    puts "Environment: #{Rails.env}"
    puts "Store Type: #{stats[:store_type]}"
    puts "Timestamp: #{stats[:timestamp]}"
    puts ""
    puts "Key Count: #{stats[:key_count]}"
    puts ""

    if stats[:error]
      puts "Note: #{stats[:error]}"
    end

    puts "=" * 60
    puts "\n"
  end

  desc "Generate detailed cache performance report"
  task report: :environment do
    monitor = CacheMonitorService.new
    report = monitor.performance_report(format: :text)

    puts report

    # Also save to file
    filename = "log/cache_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt"
    File.write(filename, report)
    puts "\nReport saved to: #{filename}"
  end

  desc "Clear all cache entries (use with caution)"
  task clear: :environment do
    print "Are you sure you want to clear ALL cache entries? [yes/NO]: "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "yes"
      monitor = CacheMonitorService.new

      if monitor.clear_cache
        puts "Cache cleared successfully"
      else
        puts "Failed to clear cache"
        exit 1
      end
    else
      puts "Cache clear cancelled"
    end
  end

  desc "Clear cache by namespace"
  task :clear_namespace, [ :namespace ] => :environment do |_t, args|
    namespace = args[:namespace]

    if namespace.blank?
      puts "Usage: rake cache:clear_namespace[namespace]"
      puts "Example: rake cache:clear_namespace[product-row]"
      exit 1
    end

    print "Clear cache namespace '#{namespace}'? [yes/NO]: "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "yes"
      monitor = CacheMonitorService.new

      if monitor.clear_cache(namespace: namespace)
        puts "Namespace '#{namespace}' cleared successfully"
      else
        puts "Failed to clear namespace"
        exit 1
      end
    else
      puts "Cache clear cancelled"
    end
  end

  desc "Warm product cache with most viewed products"
  task warm_products: :environment do
    puts "Warming product cache..."

    Company.find_each do |company|
      puts "  Company: #{company.name}"

      # Get all active products
      products = company.products.active_products.limit(100)

      monitor = CacheMonitorService.new
      result = monitor.warm_cache(
        "products_#{company.id}",
        products.to_a,
        cache_key_prefix: "product-row-v1/company-#{company.id}"
      )

      puts "    Warmed: #{result[:warmed]}, Failed: #{result[:failed]}, Duration: #{result[:duration_seconds]}s"
    end

    puts "Product cache warming complete"
  end

  desc "Test cache read/write performance"
  task test: :environment do
    puts "\n"
    puts "=" * 60
    puts "Cache Performance Test"
    puts "=" * 60
    puts ""

    monitor = CacheMonitorService.new

    # Test 1: Simple string cache
    puts "Test 1: Simple String Cache"
    result = monitor.sample_read("test-string-key") do
      "Hello, World!"
    end
    puts "  First read (miss): #{result[:duration_ms]}ms"

    result = monitor.sample_read("test-string-key") do
      "Hello, World!"
    end
    puts "  Second read (hit): #{result[:duration_ms]}ms"
    puts ""

    # Test 2: Array cache
    puts "Test 2: Array Cache (1000 items)"
    result = monitor.sample_read("test-array-key") do
      (1..1000).to_a
    end
    puts "  First read (miss): #{result[:duration_ms]}ms, Size: #{result[:value_size_bytes]} bytes"

    result = monitor.sample_read("test-array-key") do
      (1..1000).to_a
    end
    puts "  Second read (hit): #{result[:duration_ms]}ms"
    puts ""

    # Test 3: Hash cache
    puts "Test 3: Hash Cache (100 products simulation)"
    result = monitor.sample_read("test-hash-key") do
      (1..100).map do |i|
        {
          id: i,
          sku: "PRD_#{i}",
          name: "Product #{i}",
          price: rand(10.0..100.0).round(2)
        }
      end
    end
    puts "  First read (miss): #{result[:duration_ms]}ms, Size: #{result[:value_size_bytes]} bytes"

    result = monitor.sample_read("test-hash-key") do
      (1..100).map do |i|
        {
          id: i,
          sku: "PRD_#{i}",
          name: "Product #{i}",
          price: rand(10.0..100.0).round(2)
        }
      end
    end
    puts "  Second read (hit): #{result[:duration_ms]}ms"
    puts ""

    # Cleanup test keys
    Rails.cache.delete("test-string-key")
    Rails.cache.delete("test-array-key")
    Rails.cache.delete("test-hash-key")

    puts "=" * 60
    puts "Test complete (test keys cleaned up)"
    puts "=" * 60
    puts "\n"
  end

  desc "Analyze cache usage by namespace"
  task :analyze, [ :namespace ] => :environment do |_t, args|
    namespace = args[:namespace]

    if namespace.blank?
      puts "Usage: rake cache:analyze[namespace]"
      puts "Example: rake cache:analyze[product-row]"
      exit 1
    end

    puts "\n"
    puts "Analyzing cache namespace: #{namespace}"
    puts ""

    monitor = CacheMonitorService.new
    stats = monitor.namespace_stats(namespace)

    puts "Key Count: #{stats[:key_count]}"
    puts "Total Size: #{stats[:total_size_mb]} MB"
    puts "Average Size: #{stats[:avg_size_bytes]} bytes"
    puts "\n"
  end
end
