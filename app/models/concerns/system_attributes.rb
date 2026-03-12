# frozen_string_literal: true

module SystemAttributes
  extend ActiveSupport::Concern

  SYSTEM_ATTRIBUTE_GROUPS = {
    pricing:     { name: "Pricing", position: 1 },
    identifiers: { name: "Identifiers", position: 2 },
    details:     { name: "Details", position: 3 },
    physical:    { name: "Physical", position: 4 }
  }.freeze

  SYSTEM_ATTRIBUTES = {
    # --- Pricing ---
    price: {
      pa_type: :patype_number,
      view_format: :view_format_price,
      mandatory: true,
      rules: { positive: true, not_null: true },
      group: :pricing,
      shopify_field: :price,
      scope: :product_and_catalog_scope,
      name: "Price",
      description: "Product selling price in cents"
    },
    purchase_price: {
      pa_type: :patype_number,
      view_format: :view_format_price,
      group: :pricing,
      shopify_field: :cost,
      scope: :product_scope,
      name: "Purchase Price",
      description: "Supplier/wholesale cost in cents"
    },
    special_price: {
      pa_type: :patype_custom,
      view_format: :view_format_special_price,
      group: :pricing,
      custom_handler: :special_price,
      scope: :product_and_catalog_scope,
      name: "Special Price",
      description: "Sale price with date range (amount, from, until). Maps to Shopify compareAtPrice via custom handler."
    },
    vat_group: {
      pa_type: :patype_select,
      view_format: :view_format_selectable,
      group: :pricing,
      custom_handler: :vat_tag,
      scope: :product_scope,
      name: "VAT Group",
      description: "Tax classification for the product. Maps to Shopify tags via custom handler.",
      options: ["standard", "reduced 9", "reduced 14", "zero"]
    },

    # --- Identifiers ---
    ean: {
      pa_type: :patype_text,
      view_format: :view_format_ean,
      group: :identifiers,
      shopify_field: :barcode,
      scope: :product_scope,
      name: "EAN / Barcode",
      description: "EAN, UPC, or ISBN barcode"
    },
    secondary_sku: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :identifiers,
      custom_handler: :barcode_fallback,
      scope: :product_scope,
      name: "Secondary SKU",
      description: "Alternative identifier, used as barcode fallback when EAN is empty"
    },

    # --- Details ---
    description_html: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      mandatory: true,
      group: :details,
      shopify_field: :descriptionHtml,
      scope: :product_and_catalog_scope,
      name: "Description",
      description: "Main product description (rich text/HTML). Code matches pot3 convention."
    },
    short_description: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :details,
      scope: :product_and_catalog_scope,
      name: "Short Description",
      description: "Brief product summary for listings. No Shopify mapping by default."
    },
    detailed_description: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      group: :details,
      scope: :product_and_catalog_scope,
      name: "Detailed Description",
      description: "Extended product details, synced as Shopify metafield",
      shopify_metafield: {
        namespace: "global",
        key: "detailed_description_html",
        type: "multi_line_text_field"
      }
    },
    brand: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :details,
      shopify_field: :vendor,
      scope: :product_scope,
      name: "Brand",
      description: "Product brand/manufacturer"
    },

    # --- Physical ---
    weight: {
      pa_type: :patype_number,
      view_format: :view_format_weight,
      group: :physical,
      shopify_field: :weight,
      shopify_weight_unit: "GRAMS",
      scope: :product_scope,
      name: "Weight",
      description: "Product weight in grams for shipping calculations"
    },
    sizechart: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      group: :physical,
      scope: :product_scope,
      name: "Size Chart",
      description: "Size chart information, synced as Shopify metafield",
      shopify_metafield: {
        namespace: "global",
        key: "sizechart",
        type: "multi_line_text_field"
      }
    }
  }.freeze

  class_methods do
    def ensure_system_attributes!(company)
      # Create attribute groups
      SYSTEM_ATTRIBUTE_GROUPS.each do |code, config|
        company.attribute_groups.find_or_create_by!(code: code.to_s) do |group|
          group.name = config[:name]
          group.position = config[:position]
        end
      end

      # Create system attributes
      SYSTEM_ATTRIBUTES.each_with_index do |(code, config), index|
        group = company.attribute_groups.find_by(code: config[:group].to_s)

        attr = ProductAttribute.unscoped.find_or_initialize_by(company: company, code: code.to_s)
        if attr.new_record?
          attr.assign_attributes(
            name: config[:name],
            description: config[:description],
            pa_type: config[:pa_type],
            view_format: config[:view_format],
            mandatory: config.fetch(:mandatory, false),
            product_attribute_scope: config.fetch(:scope, :product_scope),
            attribute_group: group,
            attribute_position: index + 1,
            rules: build_rules(config),
            has_rules: config[:rules].present?,
            info: build_info(config)
          )
        else
          # Existing attribute: fix type/format if mismatched (bypasses immutable validation)
          expected_type = config[:pa_type].to_s
          expected_format = config[:view_format].to_s
          if attr.pa_type != expected_type || attr.view_format != expected_format
            Rails.logger.warn(
              "SystemAttributes CONFLICT: Company #{company.code} has '#{code}' " \
              "with type=#{attr.pa_type}/format=#{attr.view_format}, " \
              "expected type=#{expected_type}/format=#{expected_format}. " \
              "Forcing type/format to match system definition."
            )
            attr.update_columns(
              pa_type: ProductAttribute.pa_types[expected_type],
              view_format: ProductAttribute.view_formats[expected_format]
            )
            attr.reload
          end
        end

        # Always set system flag and metafield mapping
        attr.system = true
        if config[:shopify_metafield].present?
          attr.shopify_metafield_namespace = config[:shopify_metafield][:namespace]
          attr.shopify_metafield_key = config[:shopify_metafield][:key]
          attr.shopify_metafield_type = config[:shopify_metafield][:type]
        end

        attr.save!
      end
    end

    private

    def build_rules(config)
      return [] unless config[:rules]
      config[:rules].keys.map(&:to_s)
    end

    def build_info(config)
      info = {}
      info["options"] = config[:options] if config[:options]
      info["unit"] = config[:unit] if config[:unit]
      info
    end
  end
end
