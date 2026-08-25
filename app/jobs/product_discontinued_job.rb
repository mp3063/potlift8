# frozen_string_literal: true

class ProductDiscontinuedJob < ApplicationJob
  queue_as :default

  def perform(product)
    Rails.logger.info("Product #{product.id} (#{product.sku}) has been discontinued")

    # TODO: Implement discontinuation logic
    # - Update inventory policies
    # - Remove from active promotions
    # - Update search indices
    # - Send notifications
    # - Handle bundle/configurable impacts

    log_discontinuation(product)
  end

  private

  def log_discontinuation(product)
    Rails.logger.info({
      event: "product_discontinued",
      product_id: product.id,
      sku: product.sku,
      name: product.name,
      company_id: product.company_id,
      product_type: product.product_type,
      discontinued_at: Time.current
    }.to_json)
  end
end
