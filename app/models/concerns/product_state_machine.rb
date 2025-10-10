# frozen_string_literal: true

# ProductStateMachine
#
# Implements AASM state machine for product lifecycle management.
# Manages product status transitions with validation guards and async callbacks.
#
# States:
# - draft (0): Product in development, not ready for sale
# - active (1): Product available for sale
# - incoming (2): Product on order, not yet in stock
# - discontinuing (3): Product being phased out
# - disabled (4): Product temporarily unavailable
# - discontinued (6): Product permanently unavailable
# - deleted (999): Soft-deleted product
#
# Transitions:
# - activate: draft/disabled/incoming → active
# - discontinue: active → discontinuing
# - finish_discontinuation: discontinuing → discontinued
# - disable: active → disabled
# - delete: draft/disabled/discontinued → deleted
#
# Guards:
# - can_activate?: Validates product structure and mandatory attributes
# - structure_valid?: Checks product type-specific structure requirements
# - all_mandatory_attributes_present?: Verifies all mandatory attributes have values
#
# Callbacks:
# - notify_activation: Triggers ProductActivatedJob (async)
# - notify_discontinuation: Triggers ProductDiscontinuedJob (async)
#
module ProductStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    # AASM configuration using product_status enum column
    aasm column: :product_status, enum: true, skip_validation_on_save: true do
      # States
      state :draft, initial: true
      state :active
      state :incoming
      state :discontinuing
      state :disabled
      state :discontinued
      state :deleted

      # Transition: Activate product (make available for sale)
      # From: draft, disabled, incoming
      # To: active
      # Guards: can_activate?
      # Callbacks: notify_activation (after)
      event :activate do
        transitions from: [:draft, :disabled, :incoming], to: :active,
                    guard: :can_activate?,
                    after: :notify_activation
      end

      # Transition: Begin discontinuation process
      # From: active
      # To: discontinuing
      # Callbacks: notify_discontinuation (after)
      event :discontinue do
        transitions from: :active, to: :discontinuing,
                    after: :notify_discontinuation
      end

      # Transition: Complete discontinuation
      # From: discontinuing
      # To: discontinued
      event :finish_discontinuation do
        transitions from: :discontinuing, to: :discontinued
      end

      # Transition: Temporarily disable product
      # From: active
      # To: disabled
      event :disable do
        transitions from: :active, to: :disabled
      end

      # Transition: Soft delete product
      # From: draft, disabled, discontinued
      # To: deleted
      # Note: Using 'mark_as_deleted' instead of 'delete' to avoid conflict with ActiveRecord
      event :mark_as_deleted do
        transitions from: [:draft, :disabled, :discontinued], to: :deleted
      end
    end
  end

  # Guard: Check if product can be activated
  #
  # Validates that the product has valid structure and all mandatory
  # attributes are present before allowing activation.
  #
  # @return [Boolean] true if product can be activated
  #
  def can_activate?
    structure_valid? && all_mandatory_attributes_present?
  end

  # Guard: Validate product structure based on product type
  #
  # Validates product structure requirements:
  # - configurable: Must have subproducts via product_configurations, all must be active
  # - bundle: Must have subproducts via product_configurations, all must be active
  # - sellable: Always valid (no structure requirements)
  #
  # @return [Boolean] true if product structure is valid
  #
  def structure_valid?
    case product_type
    when "configurable"
      validate_configurable_structure
    when "bundle"
      validate_bundle_structure
    when "sellable"
      true # Sellable products have no structure requirements
    else
      false
    end
  end

  # Guard: Check if all mandatory attributes have values
  #
  # Verifies that all company mandatory attributes have been set
  # for this product.
  #
  # @return [Boolean] true if all mandatory attributes are present
  #
  def all_mandatory_attributes_present?
    mandatory_attrs = company.product_attributes.all_mandatory

    # If no mandatory attributes defined, validation passes
    return true if mandatory_attrs.empty?

    # Check that each mandatory attribute has a value
    mandatory_attrs.all? do |attr|
      value = read_attribute_value(attr.code)
      value.present?
    end
  end

  # Callback: Notify that product has been activated
  #
  # Enqueues ProductActivatedJob to handle post-activation tasks
  # (inventory updates, cache invalidation, notifications, etc.)
  #
  def notify_activation
    ProductActivatedJob.perform_later(self)
  end

  # Callback: Notify that product has been discontinued
  #
  # Enqueues ProductDiscontinuedJob to handle post-discontinuation tasks
  # (inventory adjustments, notifications, etc.)
  #
  def notify_discontinuation
    ProductDiscontinuedJob.perform_later(self)
  end

  private

  # Validate configurable product structure
  #
  # For configurable products:
  # - Must have at least one subproduct via product_configurations_as_super
  # - All subproducts must be active
  #
  # @return [Boolean] true if structure is valid
  #
  def validate_configurable_structure
    # Must have product configurations
    return false if product_configurations_as_super.empty?

    # All subproducts must be active
    subproducts.all?(&:product_status_active?)
  end

  # Validate bundle product structure
  #
  # For bundle products:
  # - Must have at least one subproduct via product_configurations_as_super
  # - All subproducts must be active
  #
  # @return [Boolean] true if structure is valid
  #
  def validate_bundle_structure
    # Must have product configurations
    return false if product_configurations_as_super.empty?

    # All subproducts must be active
    subproducts.all?(&:product_status_active?)
  end
end
