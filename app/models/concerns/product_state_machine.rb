# frozen_string_literal: true

module ProductStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    aasm column: :product_status, enum: true, skip_validation_on_save: true do
      state :draft, initial: true
      state :active
      state :incoming
      state :discontinuing
      state :disabled
      state :discontinued
      state :deleted

      event :activate do
        transitions from: [ :draft, :disabled, :incoming ], to: :active,
                    guard: :can_activate?,
                    after: :notify_activation
      end

      event :discontinue do
        transitions from: :active, to: :discontinuing,
                    after: :notify_discontinuation
      end

      event :finish_discontinuation do
        transitions from: :discontinuing, to: :discontinued
      end

      event :disable do
        transitions from: :active, to: :disabled
      end

      # Transition: Soft delete product
      # From: draft, disabled, discontinued
      # To: deleted
      # Note: Using 'mark_as_deleted' instead of 'delete' to avoid conflict with ActiveRecord
      event :mark_as_deleted do
        transitions from: [ :draft, :disabled, :discontinued ], to: :deleted
      end
    end
  end

  def can_activate?
    structure_valid? && all_mandatory_attributes_present?
  end

  # Validates product structure requirements:
  # - configurable: Must have subproducts via product_configurations, all must be active
  # - bundle: Must have subproducts via product_configurations, all must be active
  # - sellable: Always valid (no structure requirements)
  def structure_valid?
    case product_type
    when "configurable"
      validate_configurable_structure
    when "bundle"
      validate_bundle_structure
    when "sellable"
      true
    else
      false
    end
  end

  def all_mandatory_attributes_present?
    mandatory_attrs = company.product_attributes.all_mandatory

    return true if mandatory_attrs.empty?

    mandatory_attrs.all? do |attr|
      value = read_attribute_value(attr.code)
      next true if value.present?

      # Fall back to superproduct's attribute value for variants
      superproducts.any? { |sp| sp.read_attribute_value(attr.code).present? }
    end
  end

  def notify_activation
    ProductActivatedJob.perform_later(self)
  end

  def notify_discontinuation
    ProductDiscontinuedJob.perform_later(self)
  end

  private

  # For configurable products:
  # - Must have at least one subproduct via product_configurations_as_super
  # - All subproducts must be active
  def validate_configurable_structure
    # Must have product configurations
    return false if product_configurations_as_super.empty?

    # All subproducts must be active
    subproducts.all?(&:product_status_active?)
  end

  # For bundle products:
  # - Must have at least one subproduct via product_configurations_as_super
  # - All subproducts must be active
  def validate_bundle_structure
    # Must have product configurations
    return false if product_configurations_as_super.empty?

    # All subproducts must be active
    subproducts.all?(&:product_status_active?)
  end
end
