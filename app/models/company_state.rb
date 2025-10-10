# CompanyState Model
#
# Stores company-specific configuration and state information in a key-value format.
# This provides a flexible way to store per-company settings, feature flags,
# sync status, and integration states.
#
# Attributes:
# - company_id: Reference to the owning company (required)
# - code: Key identifier for the state/configuration (required)
# - state: Value for the configuration (can be nil)
#
# Examples:
# - Sync status: code='last_sync', state='2025-10-10T12:00:00Z'
# - Feature flags: code='feature_advanced_reports', state='enabled'
# - Integration states: code='shopify_integration_status', state='active'
#
# Constraints:
# - Company + code combination must be unique
# - Code is required
# - Company association is required
#
class CompanyState < ApplicationRecord
  # Associations
  belongs_to :company

  # Validations
  validates :code, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :company_id, presence: true
end
