# Ordering:
# - Uses acts_as_list for position-based ordering within a configuration
# - Allows custom ordering (e.g., XS, S, M, L, XL instead of alphabetical)
class ConfigurationValue < ApplicationRecord
  belongs_to :configuration

  validates :value, presence: true, uniqueness: { scope: :configuration_id }

  acts_as_list scope: :configuration_id

  # Delegate product access for convenience
  # Allows value.product instead of value.configuration.product
  delegate :product, to: :configuration
end
