# frozen_string_literal: true

# ProductActivatedJob
#
# Background job triggered when a product transitions to the active state.
# Handles post-activation tasks asynchronously with high priority.
#
# Queue: :high_priority (urgent operations)
#
# Responsibilities:
# - Sync product to all catalogs where it exists
# - Notify and sync superproducts (parent products)
# - Touch superproducts to update their timestamps
# - Trigger cascading updates for related products
#
# Workflow:
# 1. Find all catalogs containing this product
# 2. Sync to each catalog (respecting sync_paused flag)
# 3. Find all superproducts (parent products in bundles/configurables)
# 4. Touch superproducts to trigger their update callbacks
# 5. Sync superproducts with a 5-second delay
#
# Usage:
#   ProductActivatedJob.perform_later(product)
#
class ProductActivatedJob < ApplicationJob
  queue_as :high_priority

  # Perform product activation tasks
  #
  # @param product [Product] The product that was activated
  #
  def perform(product)
    timestamp = Time.current

    Rails.logger.info(
      "Product activation job started: Product #{product.id} (#{product.sku}) activated"
    )

    # Log activation event
    log_activation(product, timestamp)

    # Sync to all catalogs where this product exists
    sync_to_catalogs(product, timestamp)

    # Notify and sync superproducts
    notify_superproducts(product, timestamp)

    Rails.logger.info(
      "Product activation job completed: Product #{product.id} (#{product.sku})"
    )
  end

  private

  # Sync product to all its catalogs
  #
  # @param product [Product] The activated product
  # @param timestamp [Time] Activation timestamp
  #
  def sync_to_catalogs(product, timestamp)
    # Eager load catalogs to avoid N+1 queries
    catalogs = product.catalogs.includes(:company).to_a

    if catalogs.empty?
      Rails.logger.info(
        "Product #{product.id} (#{product.sku}) is not in any catalogs. Skipping catalog sync."
      )
      return
    end

    Rails.logger.info(
      "Syncing product #{product.id} (#{product.sku}) to #{catalogs.size} catalog(s)"
    )

    catalogs.each do |catalog|
      # Skip if catalog has sync paused
      if catalog.info&.dig('sync_paused')
        Rails.logger.info(
          "Catalog #{catalog.code} has sync paused. Skipping sync for product #{product.sku}."
        )
        next
      end

      # Enqueue sync job for this catalog
      ProductSyncJob.perform_later(product, catalog, timestamp)
    end
  end

  # Notify and sync superproducts (parent products)
  #
  # When a subproduct is activated, its parent products need to be updated
  # and synced to reflect the change.
  #
  # @param product [Product] The activated product
  # @param timestamp [Time] Activation timestamp
  #
  def notify_superproducts(product, timestamp)
    # Eager load superproducts with their catalogs
    superproducts = product.superproducts
                           .includes(:catalogs)
                           .to_a

    if superproducts.empty?
      Rails.logger.debug(
        "Product #{product.id} (#{product.sku}) has no superproducts. Skipping superproduct notification."
      )
      return
    end

    Rails.logger.info(
      "Notifying #{superproducts.size} superproduct(s) for product #{product.id} (#{product.sku})"
    )

    superproducts.each do |superproduct|
      # Touch the superproduct to update its timestamp
      # This will trigger its own update callbacks and change propagation
      superproduct.touch

      # Sync superproduct to its catalogs with a delay
      # The delay prevents overwhelming the sync system when many subproducts are activated
      superproduct.catalogs.each do |catalog|
        next if catalog.info&.dig('sync_paused')

        ProductSyncJob.set(wait: 5.seconds).perform_later(superproduct, catalog, timestamp)
      end

      Rails.logger.info(
        "Superproduct #{superproduct.id} (#{superproduct.sku}) touched and sync jobs enqueued"
      )
    end
  end

  # Log product activation details
  #
  # @param product [Product] The activated product
  # @param timestamp [Time] Activation timestamp
  #
  def log_activation(product, timestamp)
    Rails.logger.info({
      event: 'product_activated',
      product_id: product.id,
      sku: product.sku,
      name: product.name,
      company_id: product.company_id,
      product_type: product.product_type,
      activated_at: timestamp,
      catalogs_count: product.catalogs.count,
      superproducts_count: product.superproducts.count
    }.to_json)
  end
end
