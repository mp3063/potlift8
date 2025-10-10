# frozen_string_literal: true

# ProductActivatedJob
#
# Background job triggered when a product transitions to the active state.
# Handles post-activation tasks asynchronously.
#
# Responsibilities (to be implemented):
# - Clear product caches
# - Update inventory availability
# - Trigger search index updates
# - Send notifications to relevant stakeholders
# - Update related product calculations (bundles, configurables)
#
# Usage:
#   ProductActivatedJob.perform_later(product)
#
class ProductActivatedJob < ApplicationJob
  queue_as :default

  # Perform product activation tasks
  #
  # @param product [Product] The product that was activated
  #
  def perform(product)
    Rails.logger.info("Product #{product.id} (#{product.sku}) has been activated")

    # TODO: Implement activation logic
    # - Clear product caches
    # - Update search indices
    # - Trigger inventory updates
    # - Send notifications

    # For now, just log the event
    log_activation(product)
  end

  private

  # Log product activation details
  #
  # @param product [Product] The activated product
  #
  def log_activation(product)
    Rails.logger.info({
      event: 'product_activated',
      product_id: product.id,
      sku: product.sku,
      name: product.name,
      company_id: product.company_id,
      product_type: product.product_type,
      activated_at: Time.current
    }.to_json)
  end
end
