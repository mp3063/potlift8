# frozen_string_literal: true

class BundleSkuGeneratorService
  MAX_SKU_LENGTH = 50

  def initialize(base_sku, variant_codes)
    @base_sku = sanitize_sku_part(base_sku.to_s)
    @variant_codes = Array(variant_codes).compact
  end

  def generate
    return @base_sku if @variant_codes.empty?

    sanitized_variants = @variant_codes.map { |code| sanitize_sku_part(code) }
                                      .reject(&:empty?)

    return @base_sku if sanitized_variants.empty?

    full_sku = [ @base_sku, *sanitized_variants ].join("-")

    truncate_if_needed(full_sku)
  end

  def self.generate(base_sku, variant_codes)
    new(base_sku, variant_codes).generate
  end

  private

  def sanitize_sku_part(part)
    part.to_s
        .upcase
        .gsub(/[\s_]+/, "-")
        .gsub(/[^A-Z0-9-]/, "")
        .gsub(/-+/, "-")
        .gsub(/^-|-$/, "")
  end

  def truncate_if_needed(sku)
    return sku if sku.length <= MAX_SKU_LENGTH

    return @base_sku if @base_sku.length >= MAX_SKU_LENGTH

    available_space = MAX_SKU_LENGTH - @base_sku.length - 1

    return @base_sku if available_space <= 0

    variant_part = sku[@base_sku.length + 1..]
    truncated_variants = truncate_variant_part(variant_part, available_space)

    "#{@base_sku}-#{truncated_variants}"
  end

  def truncate_variant_part(variant_part, max_length)
    return variant_part if variant_part.length <= max_length

    variants = variant_part.split("-")
    return variants.first[0...max_length] if variants.one?

    per_variant_length = (max_length / variants.size).floor - 1

    return variant_part[0...max_length] if per_variant_length <= 0

    truncated = variants.map { |v| v[0...per_variant_length] }
                       .join("-")

    # Ensure we don't exceed max_length
    truncated[0...max_length]
  end
end
