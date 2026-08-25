# frozen_string_literal: true

# How it works:
#   1. Validates new configuration using BundleValidationService
#   2. In a transaction:
#      - Soft-deletes old variants (product_status: :deleted, deleted_at: timestamp)
#      - Stores replacement metadata in info JSONB field
#      - Generates new variants using BundleVariantGeneratorService
#   3. Returns counts of deleted and created variants
# Note:
#   - Old variants are NOT hard-deleted for audit trail
#   - They remain linked to the bundle via parent_bundle_id
#   - Transaction ensures atomicity (all or nothing)
class BundleRegeneratorService
  Result = Struct.new(:success?, :deleted_count, :created_count, :errors, keyword_init: true)

  attr_reader :bundle, :new_config, :company

  def initialize(bundle_product, new_configuration)
    @bundle = bundle_product
    @new_config = new_configuration
    @company = bundle_product.company
  end

  def call
    validation = BundleValidationService.new(new_config, company: company)
    return failure(validation.errors) unless validation.valid?

    deleted_variants = []
    new_variants = []

    begin
      committed = false
      ActiveRecord::Base.transaction do
        deleted_variants = soft_delete_old_variants

        generation_result = generate_new_variants

        unless generation_result.success?
          @generation_errors = generation_result.errors
          raise ActiveRecord::Rollback
        end

        new_variants = generation_result.variants
        committed = true
      end

      if committed && new_variants.any?
        Result.new(
          success?: true,
          deleted_count: deleted_variants.count,
          created_count: new_variants.count,
          errors: []
        )
      elsif !committed
        failure(@generation_errors || [ "Transaction rolled back" ])
      else
        failure([ "Failed to generate new variants" ])
      end
    rescue StandardError => e
      failure([ e.message ])
    end
  end

  private

  def failure(errors)
    Result.new(
      success?: false,
      deleted_count: 0,
      created_count: 0,
      errors: Array(errors)
    )
  end

  def soft_delete_old_variants
    old_variants = bundle.bundle_variants.where.not(product_status: :deleted)

    deleted = []
    old_variants.find_each do |variant|
      updated_info = (variant.info || {}).merge(
        "replaced_by_regeneration" => true,
        "replaced_at" => Time.current.iso8601
      )

      variant.update!(
        product_status: :deleted,
        deleted_at: Time.current,
        info: updated_info
      )

      deleted << variant
    end

    deleted
  end

  def generate_new_variants
    BundleVariantGeneratorService.new(bundle, new_config).call
  end
end
