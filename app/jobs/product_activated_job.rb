# frozen_string_literal: true

# Workflow:
# 1. Find all catalogs containing this product
# 2. Sync to each catalog (respecting sync_paused flag)
# 3. Find all superproducts (parent products in bundles/configurables)
# 4. Touch superproducts to trigger their update callbacks
# 5. Sync superproducts with a 5-second delay
class ProductActivatedJob < ApplicationJob
  queue_as :high_priority

  def perform(product)
    timestamp = Time.current

    Rails.logger.info(
      "Product activation job started: Product #{product.id} (#{product.sku}) activated"
    )

    log_activation(product, timestamp)

    sync_to_catalogs(product, timestamp)

    notify_superproducts(product, timestamp)

    Rails.logger.info(
      "Product activation job completed: Product #{product.id} (#{product.sku})"
    )
  end

  private

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
      if catalog.info&.dig("sync_paused")
        Rails.logger.info(
          "Catalog #{catalog.code} has sync paused. Skipping sync for product #{product.sku}."
        )
        next
      end

      ProductSyncJob.perform_later(product, catalog, timestamp)
    end
  end

  def notify_superproducts(product, timestamp)
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
      superproduct.touch

      # Sync superproduct to its catalogs with a delay
      # The delay prevents overwhelming the sync system when many subproducts are activated
      superproduct.catalogs.each do |catalog|
        next if catalog.info&.dig("sync_paused")

        ProductSyncJob.set(wait: 5.seconds).perform_later(superproduct, catalog, timestamp)
      end

      Rails.logger.info(
        "Superproduct #{superproduct.id} (#{superproduct.sku}) touched and sync jobs enqueued"
      )
    end
  end

  def log_activation(product, timestamp)
    Rails.logger.info({
      event: "product_activated",
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
