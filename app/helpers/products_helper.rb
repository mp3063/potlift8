# frozen_string_literal: true

module ProductsHelper
  # Renders a badge for product status with appropriate variant and dot indicator
  # @param product [Product] The product instance
  # @return [String] HTML badge component
  def product_status_badge(product)
    variant = case product.product_status
              when "active" then :success
              when "draft", "incoming" then :warning
              when "discontinued", "deleted" then :danger
              else :gray
              end

    render Ui::BadgeComponent.new(variant: variant, dot: true) do
      product.product_status.titleize
    end
  end

  # Renders a badge for product type with appropriate variant
  # @param product [Product] The product instance
  # @return [String] HTML badge component
  def product_type_badge(product)
    variant = case product.product_type
              when "sellable" then :info
              when "configurable" then :warning
              when "bundle" then :gray
              else :gray
              end

    render Ui::BadgeComponent.new(variant: variant) do
      product.product_type.titleize
    end
  end

  # Renders a badge for sync status based on last sync time
  # @param synced_at [Time, nil] The timestamp of last sync
  # @return [String] HTML badge component
  def sync_status_badge(synced_at)
    if synced_at && synced_at > 1.hour.ago
      render Ui::BadgeComponent.new(variant: :success, dot: true) { "Synced" }
    elsif synced_at
      render Ui::BadgeComponent.new(variant: :warning) { "Outdated" }
    else
      render Ui::BadgeComponent.new(variant: :gray) { "Never synced" }
    end
  end
end
