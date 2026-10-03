require "active_support/concern"

module AttributeValues
  extend ActiveSupport::Concern

  included do
    validate do |av|
      if (av.ready? || !av.new_record?) && broken_rule.present?
        av.errors.add(:base, "You can't give this value to #{av.product_attribute.name} as it must be #{broken_rule}")
      end
    end
  end

  def check_readiness
    self.ready = broken_rule.blank?
  end

  # Finds the first broken rule for the current value
  def broken_rule
    return nil unless product_attribute.rules.present?

    product_attribute.rules.each do |rule|
      return rule if product_attribute.send(rule, value) == false
    end
    nil
  end

  def value
    return super unless product_attribute.patype_custom?

    if product_attribute.view_format_special_price? && self.info.to_h["special_price"].present?
      return "#{self.info.to_h['special_price'].to_h['amount']},#{self.info.to_h['special_price'].to_h['from']},#{self.info.to_h['special_price'].to_h['until']}"
    end

    if product_attribute.view_format_customer_group_price? && self.info.to_h["customer_group_prices"].present?
      return self.info.to_h["customer_group_prices"].to_h.map { |k, v| "#{k}:#{v}" }.join(",")
    end

    super
  end

  def related_products
    related_products = self.info.to_h["related_products"].to_a
    Product.where(sku: related_products)
  end

  def localized_values?
    info.to_h["localized_value"].to_h.values.any? { |x| x.present? }
  end

  private

  # This method does two things:
  # 1. Touches the product to invalidate HTTP caches (ETags, fresh_when)
  # 2. Directly enqueues ProductSyncJob for each catalog that has sync enabled
  # We must enqueue sync jobs directly because ChangePropagator skips sync when
  # only updated_at changed (to avoid unnecessary syncs from simple touches).
  def propagate_change
    return unless product.present?
    return if product.destroyed?

    # Touch product to invalidate HTTP caches (ETags, fresh_when responses)
    # Note: This will trigger ChangePropagator but it will skip since only updated_at changed
    product.touch

    timestamp = Time.current

    # A configurable parent's payload carries each variant's attributes, so a variant edit re-syncs it too
    targets = ([ product ] + Product.where(id: ProductConfiguration.unscoped.where(subproduct_id: product.id).select(:superproduct_id)).product_type_configurable)
      .flat_map { |target| target.catalogs.map { |catalog| [ target, catalog ] } }

    if targets.empty?
      Rails.logger.debug(
        "ProductAttributeValue change for Product #{product.id}: no catalogs to sync"
      )
      return
    end

    Rails.logger.info(
      "ProductAttributeValue change for Product #{product.id} (#{product.sku}). " \
      "Propagating to #{targets.size} catalog sync(s)"
    )

    targets.each do |target, catalog|
      if catalog.info&.dig("sync_paused")
        Rails.logger.debug(
          "Catalog #{catalog.code} has sync paused. Recording the change without syncing."
        )
      end

      catalog.queue_product_sync(target, timestamp)
    end
  end
end
