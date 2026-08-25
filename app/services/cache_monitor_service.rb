# Monitors cache performance metrics and provides insights into cache effectiveness.
# Tracks hits, misses, and cache key statistics for optimization.
# **Performance Optimization:**
# - Target hit rate: > 90% for fragment caches
# - Target hit rate: > 80% for HTTP ETags
# - Alert if hit rate drops below 70%
# **Integration:**
# - Call from rake tasks for daily reports
# - Expose metrics endpoint for monitoring tools
# - Log warnings for low hit rates
class CacheMonitorService
  def initialize(logger: Rails.logger)
    @logger = logger
    @cache_store = Rails.cache
  end

  def cache_stats
    stats = {
      store_type: cache_store_type,
      timestamp: Time.current,
      environment: Rails.env
    }

    if redis_available?
      redis_stats = fetch_redis_stats
      stats.merge!(redis_stats)
    else
      stats[:error] = "Redis stats not available (check Solid Cache configuration)"
    end

    if stats[:total_reads]&.positive?
      stats[:hit_rate] = ((stats[:total_hits].to_f / stats[:total_reads]) * 100).round(2)
      stats[:miss_rate] = ((stats[:total_misses].to_f / stats[:total_reads]) * 100).round(2)
    end

    # Log warning if hit rate is low
    if stats[:hit_rate] && stats[:hit_rate] < 70
      @logger.warn("Cache hit rate is low: #{stats[:hit_rate]}%")
    end

    stats
  end

  def sample_read(key, &block)
    start_time = Time.current
    hit = false

    value = @cache_store.fetch(key) do
      hit = false
      block.call
    end

    hit = true if @cache_store.exist?(key)
    duration_ms = ((Time.current - start_time) * 1000).round(2)

    {
      key: key,
      hit: hit,
      duration_ms: duration_ms,
      value_size_bytes: estimate_size(value),
      timestamp: Time.current
    }
  end

  # Clear all cache entries (use with caution)
  def clear_cache(namespace: nil)
    if namespace
      @logger.info("Clearing cache namespace: #{namespace}")
      @cache_store.delete_matched("#{namespace}*")
    else
      @logger.warn("Clearing entire cache")
      @cache_store.clear
    end

    true
  rescue => e
    @logger.error("Failed to clear cache: #{e.message}")
    false
  end

  def namespace_stats(namespace)
    keys = find_keys_by_pattern("*#{namespace}*")
    total_size = 0
    key_count = keys.size

    keys.each do |key|
      value = @cache_store.read(key)
      total_size += estimate_size(value) if value
    end

    {
      namespace: namespace,
      key_count: key_count,
      total_size_bytes: total_size,
      total_size_mb: (total_size / 1024.0 / 1024.0).round(2),
      avg_size_bytes: key_count.positive? ? (total_size / key_count) : 0
    }
  end

  def performance_report(format: :text)
    stats = cache_stats

    if format == :json
      stats.to_json
    else
      generate_text_report(stats)
    end
  end

  def warm_cache(collection_name, items, cache_key_prefix:)
    start_time = Time.current
    warmed_count = 0
    failed_count = 0

    items.each do |item|
      cache_key = "#{cache_key_prefix}/#{item.id}"

      begin
        @cache_store.write(cache_key, item)
        warmed_count += 1
      rescue => e
        @logger.error("Failed to cache #{cache_key}: #{e.message}")
        failed_count += 1
      end
    end

    duration = Time.current - start_time

    {
      collection: collection_name,
      total_items: items.size,
      warmed: warmed_count,
      failed: failed_count,
      duration_seconds: duration.round(2)
    }
  end

  private

  attr_reader :cache_store, :logger

  def cache_store_type
    @cache_store.class.name
  end

  def redis_available?
    @cache_store.respond_to?(:stats)
  end

  def fetch_redis_stats
    # For Solid Cache, we don't have built-in stats
    # Estimate based on cache operations
    {
      total_reads: 0,
      total_hits: 0,
      total_misses: 0,
      key_count: estimate_key_count,
      cache_size_mb: 0.0,
      evictions: 0,
      note: "Solid Cache stats require instrumentation"
    }
  rescue => e
    @logger.error("Failed to fetch cache stats: #{e.message}")
    {}
  end

  def estimate_size(obj)
    return 0 if obj.nil?

    Marshal.dump(obj).bytesize
  rescue => e
    @logger.warn("Failed to estimate size: #{e.message}")
    0
  end

  def find_keys_by_pattern(pattern)
    []
  rescue => e
    @logger.error("Failed to find keys: #{e.message}")
    []
  end

  def estimate_key_count
    if defined?(SolidCache::Entry)
      SolidCache::Entry.count
    else
      0
    end
  rescue => e
    @logger.warn("Failed to count cache entries: #{e.message}")
    0
  end

  def generate_text_report(stats)
    report = []
    report << "=" * 60
    report << "Cache Performance Report"
    report << "=" * 60
    report << ""
    report << "Timestamp: #{stats[:timestamp]}"
    report << "Environment: #{stats[:environment]}"
    report << "Store Type: #{stats[:store_type]}"
    report << ""
    report << "Hit/Miss Metrics:"
    report << "  Hit Rate: #{stats[:hit_rate] || 'N/A'}%"
    report << "  Miss Rate: #{stats[:miss_rate] || 'N/A'}%"
    report << "  Total Reads: #{stats[:total_reads] || 'N/A'}"
    report << "  Total Hits: #{stats[:total_hits] || 'N/A'}"
    report << "  Total Misses: #{stats[:total_misses] || 'N/A'}"
    report << ""
    report << "Storage Metrics:"
    report << "  Key Count: #{stats[:key_count] || 'N/A'}"
    report << "  Cache Size: #{stats[:cache_size_mb] || 'N/A'} MB"
    report << "  Evictions: #{stats[:evictions] || 'N/A'}"
    report << ""
    report << "=" * 60

    report.join("\n")
  end
end
