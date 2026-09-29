# frozen_string_literal: true

# Tells the catalog's external system that a destroyed product is gone.
# Takes the sku, not the product: the record no longer exists when this runs.
class ProductRemovalJob < ApplicationJob
  queue_as :default

  def perform(sku, catalog_id)
    catalog = Catalog.find_by(id: catalog_id)
    return unless catalog&.shop_connected?

    result = ProductSyncService.new(nil, catalog).remove_from_external_system(sku)
    raise "Removing #{sku} from catalog #{catalog.code} failed: #{result.error}" unless result.success?
  end
end
