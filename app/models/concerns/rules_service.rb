# RulesService Module
#
# Provides validation rule methods for ProductAttribute rules engine.
# Rules are stored in the ProductAttribute.rules jsonb column and applied
# to ProductAttributeValue values during validation.
#
# Available rules:
# - positive: Value must be a positive integer (> 0)
# - not_null: Value must be present
#
# Usage:
#   product_attribute.rules = ['positive', 'not_null']
#   product_attribute.positive(value) # => true/false
#   product_attribute.not_null(value) # => true/false
#
module RulesService
  # Validates that a value is a positive integer (> 0)
  #
  # @param value [String, Integer] The value to validate
  # @return [Boolean] true if value is a positive integer, false otherwise
  #
  # @example
  #   positive("100") # => true
  #   positive("0")   # => false
  #   positive("-5")  # => false
  #   positive("abc") # => false
  #
  def positive(value)
    return false unless is_num?(value)
    value.to_i > 0
  end

  # Validates that a value is present (not blank)
  #
  # @param value [Object] The value to validate
  # @return [Boolean] true if value is present, false if blank
  #
  # @example
  #   not_null("hello") # => true
  #   not_null("")      # => false
  #   not_null(nil)     # => false
  #
  def not_null(value)
    value.present?
  end

  private

  # Checks if a string can be converted to an integer
  #
  # @param str [String] The string to check
  # @return [Boolean] true if string is numeric, false otherwise
  #
  def is_num?(str)
    !!Integer(str)
  rescue ArgumentError, TypeError
    false
  end
end
