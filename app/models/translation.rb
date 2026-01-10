# Translation Model
#
# Provides multi-language support for products and other models.
# Uses polymorphic association to support translation of any model.
#
# Supported Locales:
# - en: English
# - es: Spanish (Español)
# - fr: French (Français)
# - de: German (Deutsch)
# - it: Italian (Italiano)
# - pt: Portuguese (Português)
#
# Usage:
# - product.translations.create!(locale: 'es', key: 'name', value: 'Producto')
# - product.translations.for_locale('es').find_by(key: 'name')&.value
#
class Translation < ApplicationRecord
  # Polymorphic association
  belongs_to :translatable, polymorphic: true

  # Supported locales
  SUPPORTED_LOCALES = %w[en es fr de it pt].freeze

  # Locale names for UI
  LOCALE_NAMES = {
    "en" => "English",
    "es" => "Español",
    "fr" => "Français",
    "de" => "Deutsch",
    "it" => "Italiano",
    "pt" => "Português"
  }.freeze

  # Validations
  validates :locale, presence: true, inclusion: { in: SUPPORTED_LOCALES }
  validates :key, presence: true
  validates :locale, uniqueness: { scope: [ :translatable_type, :translatable_id, :key ] }

  # Scopes
  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :for_key, ->(key) { where(key: key) }

  # Get locale display name
  #
  # @return [String] Human-readable locale name
  #
  def locale_name
    LOCALE_NAMES[locale] || locale.upcase
  end

  # Class method to get all locale options for forms
  #
  # @return [Array<Array>] Array of [name, code] pairs
  #
  def self.locale_options
    SUPPORTED_LOCALES.map { |code| [ LOCALE_NAMES[code], code ] }
  end
end
