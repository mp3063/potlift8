# frozen_string_literal: true

module Products
  class SyncPreviewComponent < ViewComponent::Base
    attr_reader :product, :catalog, :catalog_item, :payload, :shopify_data

    # The sent load carries these product fields flat at its top level (ProductSyncService#build_shopify_load_data)
    SENT_PRODUCT_FIELDS = %w[sku ean name product_type product_status configuration_type
                             total_saldo total_max_sellable_saldo].freeze

    def initialize(product:, catalog:, catalog_item:, payload:, shopify_data: nil)
      @product = product
      @catalog = catalog
      @catalog_item = catalog_item
      @payload = payload
      @shopify_data = shopify_data
    end

    def has_shopify_comparison?
      shopify_data.present? && shopify_data[:last_payload].present?
    end

    def shopify_product_status
      @shopify_data&.dig(:shopify_product, :status)
    end

    def shopify_product_data
      @shopify_data&.dig(:shopify_product, :shopify_data)
    end

    def shopify_variant_weights
      return [] unless shopify_product_data

      edges = shopify_product_data.dig(:variants, :edges) || shopify_product_data.dig("variants", "edges") || []
      edges.filter_map do |edge|
        node = edge[:node] || edge["node"]
        next unless node

        weight_data = node.dig(:inventoryItem, :measurement, :weight) ||
                      node.dig("inventoryItem", "measurement", "weight")
        {
          sku: node[:sku] || node["sku"],
          weight: weight_data && (weight_data[:value] || weight_data["value"]),
          unit: weight_data && (weight_data[:unit] || weight_data["unit"])
        }
      end
    end

    def last_synced_at
      return nil unless shopify_data&.dig(:last_synced_at)

      Time.parse(shopify_data[:last_synced_at])
    end

    def payload_sections
      [
        { key: :product, title: "Basic Product Info" },
        { key: :attributes, title: "Attributes" },
        { key: :labels, title: "Labels" },
        { key: :assets, title: "Assets & Images" },
        { key: :inventory, title: "Inventory" },
        { key: :translations, title: "Translations" },
        { key: :configurations, title: "Configurations" },
        { key: :subproducts, title: "Variants / Bundle Items" }
      ].select { |s| payload[s[:key]].present? }
    end

    def section_data(section_key)
      has_shopify_comparison? ? load_section(sent_load, section_key) : payload[section_key]
    end

    def diff_section(section_key)
      return nil unless has_shopify_comparison?

      @diffs ||= {}
      return @diffs[section_key] if @diffs.key?(section_key)

      local = section_data(section_key)
      remote = load_section(stored_load, section_key)
      @diffs[section_key] = (field_changes(local, remote).to_h if local.present? && remote.present?)
    end

    # Rows are [key, value, changes]; one block for a hash section, one per item for an array section
    def section_blocks(section_key)
      local = section_data(section_key)
      remote = load_section(stored_load, section_key) if has_shopify_comparison?
      return [ { prefix: nil, rows: diff_rows(section_key, local, remote) } ] if local.is_a?(Hash)

      remote = [] unless remote.is_a?(Array)
      changes = diff_section(section_key) || {}
      Array.new([ local.size, remote.size ].max) do |i|
        mine, theirs = local[i], remote[i]
        whole = changes[i.to_s]
        marker = if whole && mine.nil? then "Only in Shopify"
        elsif whole && theirs.nil? then "Not in Shopify yet"
        end
        item = mine.nil? ? theirs : mine
        rows = if item.is_a?(Hash)
          diff_rows(section_key, item, theirs, i.to_s)
        else
          [ [ nil, item, marker ? {} : changes.slice(i.to_s) ] ]
        end
        { prefix: i.to_s, marker: marker, rows: rows }
      end
    end

    def format_value(value)
      case value
      when nil
        tag.span("null", class: "text-gray-400 italic")
      when true, false
        tag.span(value.to_s, class: value ? "text-green-600 font-medium" : "text-red-600 font-medium")
      when Hash
        tag.code(value.to_json.truncate(120), class: "text-xs font-mono bg-gray-100 text-gray-700 px-1.5 py-0.5 rounded break-all")
      when Array
        tag.span("#{value.size} items", class: "text-gray-500")
      when String
        value.truncate(200)
      else
        value.to_s
      end
    end

    private

    def sent_load
      @sent_load ||= JSON.parse(ProductSyncService.new(product, catalog).build_shopify_load_data(payload).to_json)
    end

    def stored_load
      @stored_load ||= shopify_data[:last_payload].deep_stringify_keys
    end

    def diff_rows(section_key, local, remote, prefix = nil)
      remote = {} unless remote.is_a?(Hash)
      changes = diff_section(section_key) || {}
      (local.keys | remote.keys).map do |key|
        path = [ prefix, key ].compact.join(".")
        [ key, local[key], changes.select { |p, _| p == path || p.start_with?("#{path}.") } ]
      end
    end

    def field_changes(local, remote, path = nil)
      if local.is_a?(Hash) && remote.is_a?(Hash)
        (local.keys | remote.keys).flat_map { |key| field_changes(local[key], remote[key], [ path, key ].compact.join(".")) }
      elsif local.is_a?(Array) && remote.is_a?(Array)
        Array.new([ local.size, remote.size ].max) { |i| field_changes(local[i], remote[i], [ path, i ].compact.join(".")) }.flatten(1)
      elsif local == remote
        []
      else
        [ [ path, { potlift: local, shopify: remote } ] ]
      end
    end

    def load_section(load, section_key)
      section_key == :product ? load.slice(*SENT_PRODUCT_FIELDS) : load[section_key.to_s]
    end
  end
end
