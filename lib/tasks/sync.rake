# frozen_string_literal: true

namespace :sync do
  desc "Reconcile catalog item sync status with Shopify8 (checks which products actually exist)"
  task reconcile: :environment do
    catalog_code = ENV["CATALOG"]
    abort "CATALOG is required. Usage: bin/rails sync:reconcile CATALOG=WEB-EUR" unless catalog_code.present?
    dry_run = ENV["DRY_RUN"] != "false"

    catalog = Catalog.where("UPPER(code) = ?", catalog_code.upcase).first
    abort "Catalog '#{catalog_code}' not found" unless catalog
    abort "Catalog '#{catalog_code}' is not connected to Shopify" unless catalog.shopify_connected?

    puts "Reconciling sync status for catalog: #{catalog.code} (#{catalog.name})"
    puts "Shopify8 shop_id: #{catalog.shop_id}"
    puts "Mode: #{dry_run ? 'DRY RUN (set DRY_RUN=false to apply)' : 'LIVE'}"
    puts

    shopify8_url = ENV.fetch("SHOPIFY8_URL", "http://localhost:3245")
    api_token = catalog.company.api_token

    # Fetch existing SKUs from Shopify8
    response = Faraday.get("#{shopify8_url}/api/v1/products") do |req|
      req.headers["Authorization"] = "Bearer #{api_token}"
      req.headers["Content-Type"] = "application/json"
      req.params["shop_id"] = catalog.shop_id
      req.options.timeout = 30
    end

    unless response.success?
      # Fall back: if the products endpoint doesn't exist, just reset all synced items
      puts "Could not fetch products from Shopify8 (#{response.status}). Falling back to full reset."
      puts "This will reset ALL synced catalog items to never_synced."
      puts

      synced_items = catalog.catalog_items.where(sync_status: :synced)
      puts "Found #{synced_items.count} catalog items with sync_status=synced"

      unless dry_run
        reset_count = 0
        synced_items.find_each do |item|
          item.update!(
            sync_status: :never_synced,
            last_synced_at: nil,
            last_sync_error: "Reset by sync:reconcile task"
          )
          reset_count += 1
        end
        puts "Reset #{reset_count} catalog items to never_synced"
      end
      next
    end

    shopify8_products = JSON.parse(response.body)
    shopify8_skus = if shopify8_products.is_a?(Hash) && shopify8_products["data"]
                      shopify8_products["data"].map { |p| p["sku"] }
                    elsif shopify8_products.is_a?(Array)
                      shopify8_products.map { |p| p["sku"] }
                    else
                      []
                    end

    puts "Products in Shopify8: #{shopify8_skus.size}"
    puts "SKUs: #{shopify8_skus.join(', ')}" if shopify8_skus.size <= 20
    puts

    synced_items = catalog.catalog_items.includes(:product).where(sync_status: :synced)
    stale_count = 0
    valid_count = 0

    synced_items.find_each do |item|
      sku = item.product.sku
      if shopify8_skus.include?(sku)
        valid_count += 1
      else
        stale_count += 1
        puts "  STALE: #{sku} (catalog_item ##{item.id}) — not found in Shopify8"

        unless dry_run
          item.update!(
            sync_status: :never_synced,
            last_synced_at: nil,
            last_sync_error: "Product not found in Shopify8 (reconciliation)"
          )
        end
      end
    end

    puts
    puts "Summary:"
    puts "  Valid (still in Shopify8): #{valid_count}"
    puts "  Stale (reset to never_synced): #{stale_count}"
    puts
    puts dry_run ? "DRY RUN complete. Run with DRY_RUN=false to apply changes." : "Reconciliation complete."
  end

  desc "Reset sync status for all items in a catalog"
  task reset: :environment do
    catalog_code = ENV["CATALOG"]
    abort "CATALOG is required. Usage: bin/rails sync:reset CATALOG=WEB-EUR" unless catalog_code.present?

    catalog = Catalog.where("UPPER(code) = ?", catalog_code.upcase).first
    abort "Catalog '#{catalog_code}' not found" unless catalog

    synced_items = catalog.catalog_items.where.not(sync_status: :never_synced)
    count = synced_items.count

    puts "Resetting #{count} catalog items in #{catalog.code} to never_synced..."

    reset_count = 0
    synced_items.find_each do |item|
      item.update!(
        sync_status: :never_synced,
        last_synced_at: nil,
        last_sync_error: "Reset by sync:reset task"
      )
      reset_count += 1
    end

    puts "Done. Reset #{reset_count} catalog items."
  end
end
