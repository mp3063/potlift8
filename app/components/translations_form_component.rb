# frozen_string_literal: true

class TranslationsFormComponent < ViewComponent::Base
  attr_reader :model, :available_locales, :form, :default_locale

  LOCALES = {
    en: { name: "English", flag: "🇬🇧" },
    sv: { name: "Swedish", flag: "🇸🇪" },
    no: { name: "Norwegian", flag: "🇳🇴" },
    da: { name: "Danish", flag: "🇩🇰" },
    fi: { name: "Finnish", flag: "🇫🇮" },
    de: { name: "German", flag: "🇩🇪" },
    fr: { name: "French", flag: "🇫🇷" },
    es: { name: "Spanish", flag: "🇪🇸" }
  }.freeze

  def initialize(model:, available_locales:, form: nil, default_locale: :en)
    @model = model
    @available_locales = available_locales
    @form = form
    @default_locale = default_locale
  end

  def locale_config(locale)
    LOCALES[locale] || { name: locale.to_s.upcase, flag: "" }
  end

  def translation_for(locale)
    if model.respond_to?(:translations)
      model.translations.find_or_initialize_by(locale: locale.to_s)
    else
      # Fallback if model doesn't support translations
      OpenStruct.new(locale: locale.to_s, name: "", description: "")
    end
  end

  def default_locale?(locale)
    locale.to_sym == default_locale.to_sym
  end

  def panel_id(locale)
    "translation-panel-#{locale}"
  end

  def tab_id(locale)
    "translation-tab-#{locale}"
  end

  def tab_classes(locale)
    base = "px-4 py-2 text-sm font-medium transition-colors duration-150 border-b-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"

    if default_locale?(locale)
      "#{base} border-blue-600 text-blue-600"
    else
      "#{base} border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end
end
