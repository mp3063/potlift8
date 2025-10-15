# ConfigurationValue Model
#
# Represents individual values for a configuration dimension.
# Each value is an option for the configuration (e.g., "Small" for Size configuration).
#
# Example:
# For a Size configuration:
#   - ConfigurationValue: "Small"
#   - ConfigurationValue: "Medium"
#   - ConfigurationValue: "Large"
#
# For a Color configuration:
#   - ConfigurationValue: "Red"
#   - ConfigurationValue: "Blue"
#   - ConfigurationValue: "Green"
#
# Ordering:
# - Uses acts_as_list for position-based ordering within a configuration
# - Allows custom ordering (e.g., XS, S, M, L, XL instead of alphabetical)
#
# Delegation:
# - Delegates product access to parent configuration for convenience
#
class ConfigurationValue < ApplicationRecord
  # Association to parent configuration
  belongs_to :configuration

  # Validations
  validates :value, presence: true, uniqueness: { scope: :configuration_id }

  # Position-based ordering within a configuration
  # Allows custom ordering of values (e.g., size ordering)
  acts_as_list scope: :configuration_id

  # Delegate product access for convenience
  # Allows value.product instead of value.configuration.product
  delegate :product, to: :configuration
end
