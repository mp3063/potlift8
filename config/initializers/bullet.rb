# Bullet Configuration
#
# Bullet helps detect N+1 queries, unused eager loading, and missing counter caches.
# It monitors ActiveRecord queries and relationships to identify performance issues.
#
# Configuration:
# - Enabled only in development and test environments
# - Alerts displayed in browser console
# - Warnings logged to Rails logger
# - Console output for quick debugging
#
# Common N+1 Scenarios to Watch For:
# - Iterating over associations without eager loading
# - Accessing attributes through multiple levels of associations
# - Counter operations without counter_cache columns
#
# How to Fix N+1 Queries:
# 1. Use includes/eager_load/preload for associations
# 2. Use joins for filtering without loading associations
# 3. Add counter_cache columns for count operations
# 4. Implement custom caching strategies for complex calculations
#
# Example:
#   # Bad (N+1)
#   Product.all.each { |p| p.inventories.sum(:value) }
#
#   # Good (eager loading)
#   Product.includes(:inventories).each { |p| p.inventories.sum(:value) }
#
if defined?(Bullet)
  Bullet.enable = true

  # Development Environment Configuration
  if Rails.env.development?
    # Browser notification in footer of pages (disabled - use logs instead)
    Bullet.alert = false

    # Log to Rails logger
    Bullet.bullet_logger = true

    # Console output for quick visibility
    Bullet.console = true

    # Log to bullet.log file in log directory
    Bullet.rails_logger = true

    # Add HTTP headers with Bullet warnings
    Bullet.add_footer = true
  end

  # Test Environment Configuration
  if Rails.env.test?
    # Raise errors in tests to catch N+1 queries during development
    # Set to false in CI if you want tests to pass with warnings instead
    Bullet.raise = true

    # Log warnings to bullet.log
    Bullet.bullet_logger = true

    # Detect N+1 queries
    Bullet.n_plus_one_query_enable = true

    # Disable unused eager loading detection in tests (causes false positives with find_each)
    # find_each loads records in batches, so eager loading may not be used
    Bullet.unused_eager_loading_enable = false

    # Detect missing counter cache columns
    Bullet.counter_cache_enable = true
  end

  # Development Environment Configuration - Common settings
  if Rails.env.development?
    # Detect N+1 queries
    Bullet.n_plus_one_query_enable = true

    # Detect unused eager loading (false positives can occur, monitor carefully)
    Bullet.unused_eager_loading_enable = true

    # Detect missing counter cache columns
    Bullet.counter_cache_enable = true

    # Skip checking for certain models or associations that are known to be okay
    # Bullet.add_safelist type: :n_plus_one_query, class_name: "Product", association: :inventories
  end
end
