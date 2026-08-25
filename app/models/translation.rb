class Translation < ApplicationRecord
  belongs_to :translatable, polymorphic: true

  SUPPORTED_LOCALES = %w[en es fr de it pt].freeze

  LOCALE_NAMES = {
    "en" => "English",
    "es" => "Español",
    "fr" => "Français",
    "de" => "Deutsch",
    "it" => "Italiano",
    "pt" => "Português"
  }.freeze

  validates :locale, presence: true, inclusion: { in: SUPPORTED_LOCALES }
  validates :key, presence: true
  validates :locale, uniqueness: { scope: [ :translatable_type, :translatable_id, :key ] }

  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :for_key, ->(key) { where(key: key) }

  def locale_name
    LOCALE_NAMES[locale] || locale.upcase
  end

  def self.locale_options
    SUPPORTED_LOCALES.map { |code| [ LOCALE_NAMES[code], code ] }
  end
end
