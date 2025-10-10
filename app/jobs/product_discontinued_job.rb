# frozen_string_literal: true

# ProductDiscontinuedJob
#
# Background job triggered when a product begins the discontinuation process.
# Handles post-discontinuation tasks asynchronously.
#
# Responsibilities (to be implemented):
# - Update inventory reservation rules
# - Clear product from active promotions
# - Trigger search index updates
# - Send notifications to relevant stakeholders
# - Update related product calculations (bundles, configurables)
# - Schedule inventory clearance tasks
#
# Usage:
#   ProductDiscontinuedJob.perform_later(product)
#
class ProductDiscontinuedJob < ApplicationJob
  queue_as :default

  # Perform product discontinuation tasks
  #
  # @param product [Product] The product being discontinued
  #
  def perform(product)
    Rails.logger.info("Product #{product.id} (#{product.sku}) has been discontinued")

    # TODO: Implement discontinuation logic
    # - Update inventory policies
    # - Remove from active promotions
    # - Update search indices
    # - Send notifications
    # - Handle bundle/configurable impacts

    # For now, just log the event
    log_discontinuation(product)
  end

  private

  # Log product discontinuation details
  #
  # @param product [Product] The discontinued product
  #
  def log_discontinuation(product)
    Rails.logger.info({
      event: 'product_discontinued',
      product_id: product.id,
      sku: product.sku,
      name: product.name,
      company_id: product.company_id,
      product_type: product.product_type,
      discontinued_at: Time.current
    }.to_json)
  end
end
