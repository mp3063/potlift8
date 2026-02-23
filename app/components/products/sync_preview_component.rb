# frozen_string_literal: true

module Products
  class SyncPreviewComponent < ViewComponent::Base
    attr_reader :product, :catalog, :catalog_item, :payload, :shopify_data

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

    def diff_section(section_key)
      return nil unless has_shopify_comparison?

      potlift_data = payload[section_key]
      shopify_data_section = shopify_data[:last_payload]&.dig(section_key.to_s)
      return nil unless potlift_data.present? && shopify_data_section.present?

      compute_diff(potlift_data, shopify_data_section)
    end

    def format_value(value)
      case value
      when nil
        tag.span("null", class: "text-gray-400 italic")
      when true, false
        tag.span(value.to_s, class: value ? "text-green-600 font-medium" : "text-red-600 font-medium")
      when Hash
        tag.code(value.to_json.truncate(120), class: "text-xs font-mono bg-gray-100 text-gray-700 px-1.5 py-0.5 rounded")
      when Array
        tag.span("#{value.size} items", class: "text-gray-500")
      when String
        value.truncate(200)
      else
        value.to_s
      end
    end

    private

    def compute_diff(local, remote)
      return { status: :match } if normalize(local) == normalize(remote)

      changes = []
      if local.is_a?(Hash) && remote.is_a?(Hash)
        all_keys = (local.keys.map(&:to_s) + remote.keys.map(&:to_s)).uniq
        all_keys.each do |key|
          l_val = local[key] || local[key.to_sym]
          r_val = remote[key] || remote[key.to_sym]
          if normalize(l_val) != normalize(r_val)
            changes << { field: key, potlift: l_val, shopify: r_val }
          end
        end
      end

      { status: changes.empty? ? :match : :changed, changes: changes }
    end

    def normalize(value)
      case value
      when Hash
        value.transform_keys(&:to_s).transform_values { |v| normalize(v) }
      when Array
        value.map { |v| normalize(v) }
      else
        value
      end
    end
  end
end
