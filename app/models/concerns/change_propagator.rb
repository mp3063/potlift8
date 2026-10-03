# frozen_string_literal: true

# Key Features:
# - Propagates updates to all catalogs containing the product
# - Propagates destroy events for cleanup
# - Skips sync if catalog has sync_paused flag
# - Prevents infinite loops by checking for meaningful changes
# - Touches superproducts to cascade changes
# - Eager loads catalogs to prevent N+1 queries
# Workflow:
# 1. Product is updated -> after_commit callback fires
# 2. Check if meaningful changes occurred (not just updated_at)
# 3. Find all catalogs containing this product
# 4. Record the change and queue a sync per catalog (Catalog#queue_product_sync)
# 5. Touch superproducts to trigger their propagation
module ChangePropagator
  extend ActiveSupport::Concern

  included do
    # Use after_commit to avoid syncing during transaction
    # This prevents syncing changes that might be rolled back
    after_commit :propagate_changes_on_update, on: :update
    after_commit :propagate_changes_on_destroy, on: :destroy
    # prepend: catalog_items are destroyed (dependent: :destroy) before after_commit
    before_destroy :capture_removal_catalog_ids, prepend: true
  end

  # AASM persists status with update_all, which skips the after_commit above,
  # so status events call this from their own after_commit hook.
  def propagate_status_change
    propagate_to_catalogs(Time.current)
    touch_superproducts
  end

  private

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

    propagate_to_catalogs(timestamp)

    touch_superproducts
  end

  def propagate_changes_on_destroy
    Rails.logger.info(
      "Propagating destroy for #{self.class.name} #{id} (#{try(:sku) || 'N/A'})"
    )

    timestamp = Time.current

    Rails.logger.info({
      event: "product_destroyed",
      product_id: id,
      product_sku: try(:sku),
      destroyed_at: timestamp
    }.to_json)

    Array(@removal_catalog_ids).each do |catalog_id|
      ProductRemovalJob.perform_later(sku, catalog_id)
    end
  end

  # One removal per shop: several catalogs can point at the same shop
  def capture_removal_catalog_ids
    @removal_catalog_ids = catalogs
      .reject { |catalog| catalog.info&.dig("sync_paused") }
      .select(&:shop_connected?)
      .uniq(&:shop_key)
      .map(&:id)
  end

  def propagate_to_catalogs(timestamp)
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
      if catalog.info&.dig("sync_paused")
        Rails.logger.debug(
          "Catalog #{catalog.code} has sync paused. Recording the change without syncing."
        )
      end

      catalog.queue_product_sync(self, timestamp)
    end
  end

  def touch_superproducts
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
