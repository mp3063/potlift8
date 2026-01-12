# frozen_string_literal: true

# ProductTranslations
#
# Handles product translation helper methods for multi-language support.
# Works with the polymorphic translations association.
#
module ProductTranslations
  extend ActiveSupport::Concern

  def translated_name(locale = I18n.locale)
    translations.find_by(locale: locale.to_s, key: "name")&.value || name
  end

  def translated_description(locale = I18n.locale)
    translations.find_by(locale: locale.to_s, key: "description")&.value || description
  end

  def set_translated_name(locale, value)
    translation = translations.find_or_initialize_by(locale: locale.to_s, key: "name")
    translation.value = value
    translation.save!
    translation
  end

  def set_translated_description(locale, value)
    translation = translations.find_or_initialize_by(locale: locale.to_s, key: "description")
    translation.value = value
    translation.save!
    translation
  end
end
