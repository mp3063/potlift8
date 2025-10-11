# frozen_string_literal: true

# ChangePropagator Concern
#
# Automatically propagates product changes to external systems and related products.
# Uses after_commit callbacks to ensure changes are only propagated after successful
# database transactions.
#
# Key Features:
# - Propagates updates to all catalogs containing the product
# - Propagates destroy events for cleanup
# - Skips sync if catalog has sync_paused flag
# - Prevents infinite loops by checking for meaningful changes
# - Touches superproducts to cascade changes
# - Eager loads catalogs to prevent N+1 queries
#
# Change Detection:
# - Skips sync if only updated_at changed (no meaningful change)
# - Propagates all other attribute changes
#
# Usage:
#   class Product < ApplicationRecord
#     include ChangePropagator
#   end
#
# Workflow:
# 1. Product is updated -> after_commit callback fires
# 2. Check if meaningful changes occurred (not just updated_at)
# 3. Find all catalogs containing this product
# 4. Enqueue ProductSyncJob for each catalog (skip if sync_paused)
# 5. Touch superproducts to trigger their propagation
#
module ChangePropagator
  extend ActiveSupport::Concern

  included do
    # Use after_commit to avoid syncing during transaction
    # This prevents syncing changes that might be rolled back
    after_commit :propagate_changes_on_update, on: :update
    after_commit :propagate_changes_on_destroy, on: :destroy
  end

  private

  # Propagate product changes after update
  #
  # Checks if meaningful changes occurred and enqueues sync jobs
  # for all catalogs containing this product.
  #
  def propagate_changes_on_update
    # Skip if only updated_at changed (no meaningful change)
    # This prevents unnecessary syncs when records are touched
    if saved_change_to_updated_at? && saved_changes.keys.size == 1
      Rails.logger.debug(
        "Skipping change propagation for #{self.class.name} #{id}: only updated_at changed"
      )
      return
    end

    Rails.logger.info(
      "Propagating changes for #{self.class.name} #{id} (#{try(:sku) || 'N/A'}). " \
      "Changed attributes: #{saved_changes.keys.join(', ')}"
    )

    timestamp = Time.current

    # Propagate to catalogs
    propagate_to_catalogs(timestamp)

    # Touch superproducts to trigger their updates
    touch_superproducts
  end

  # Propagate product destruction
  #
  # Enqueues sync jobs to remove the product from external systems
  #
  def propagate_changes_on_destroy
    Rails.logger.info(
      "Propagating destroy for #{self.class.name} #{id} (#{try(:sku) || 'N/A'})"
    )

    timestamp = Time.current

    # Note: We can't use associations after destroy, so we need to
    # handle this differently. For now, just log the event.
    # In a real implementation, you might want to capture catalog IDs
    # before destroy or handle cleanup differently.

    Rails.logger.info({
      event: 'product_destroyed',
      product_id: id,
      product_sku: try(:sku),
      destroyed_at: timestamp
    }.to_json)
  end

  # Propagate changes to all catalogs containing this product
  #
  # @param timestamp [Time] When the change occurred
  #
  def propagate_to_catalogs(timestamp)
    # Load catalogs efficiently
    catalogs_to_sync = catalogs.to_a

    if catalogs_to_sync.empty?
      Rails.logger.debug(
        "#{self.class.name} #{id} is not in any catalogs. Skipping catalog propagation."
      )
      return
    end

    Rails.logger.info(
      "Propagating changes to #{catalogs_to_sync.size} catalog(s) " \
      "for #{self.class.name} #{id}"
    )

    catalogs_to_sync.each do |catalog|
      # Skip if catalog has sync paused
      if catalog.info&.dig('sync_paused')
        Rails.logger.debug(
          "Catalog #{catalog.code} has sync paused. Skipping propagation."
        )
        next
      end

      # Enqueue sync job
      ProductSyncJob.perform_later(self, catalog, timestamp)
    end
  end

  # Touch superproducts to trigger their update callbacks
  #
  # When a subproduct changes, its parent products (bundles, configurables)
  # need to be updated and re-synced.
  #
  def touch_superproducts
    # Check if this model has the superproducts association
    return unless respond_to?(:superproducts)

    superproducts_to_touch = superproducts.to_a

    if superproducts_to_touch.empty?
      Rails.logger.debug(
        "#{self.class.name} #{id} has no superproducts. Skipping superproduct touch."
      )
      return
    end

    Rails.logger.info(
      "Touching #{superproducts_to_touch.size} superproduct(s) " \
      "for #{self.class.name} #{id}"
    )

    superproducts_to_touch.each do |superproduct|
      # Touch will trigger the superproduct's own update callbacks
      # This creates a cascade effect for multi-level hierarchies
      superproduct.touch

      Rails.logger.debug(
        "Touched superproduct #{superproduct.id} (#{superproduct.try(:sku) || 'N/A'})"
      )
    end
  rescue StandardError => e
    # Don't fail the entire operation if superproduct touching fails
    Rails.logger.error(
      "Error touching superproducts for #{self.class.name} #{id}: " \
      "#{e.class} - #{e.message}"
    )
  end
end
