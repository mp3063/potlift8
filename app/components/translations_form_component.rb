# frozen_string_literal: true

# TranslationsFormComponent - Multi-locale translation form with tabs
#
# Provides a tabbed interface for editing translations across multiple locales.
# Each locale has its own tab panel with name and description fields.
#
# **Features:**
# - Tab navigation for each locale
# - Active tab highlighting (blue-600)
# - Name and description fields per locale
# - Accessible tab controls with ARIA attributes
# - Keyboard navigation support
# - Responsive design
# - Integrates with Stimulus controller for tab switching
#
# @example Basic usage
#   <%= render TranslationsFormComponent.new(
#     model: @product,
#     available_locales: [:en, :sv, :no]
#   ) %>
#
# @example With form builder
#   <%= form_with model: @product do |f| %>
#     <%= render TranslationsFormComponent.new(
#       model: @product,
#       available_locales: [:en, :sv, :no],
#       form: f
#     ) %>
#   <% end %>
#
# @see app/javascript/controllers/translation_tabs_controller.js
# @see docs/DESIGN_SYSTEM.md Design System Documentation
#
class TranslationsFormComponent < ViewComponent::Base
  attr_reader :model, :available_locales, :form, :default_locale

  # Available locale configurations
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

  # Initialize a new translations form component
  #
  # @param model [ActiveRecord::Base] Model instance to translate (must respond to translations)
  # @param available_locales [Array<Symbol>] Array of locale codes to show tabs for
  # @param form [ActionView::Helpers::FormBuilder, nil] Optional form builder instance
  # @param default_locale [Symbol] Default locale to show first (defaults to :en)
  #
  # @example
  #   TranslationsFormComponent.new(
  #     model: product,
  #     available_locales: [:en, :sv, :no],
  #     form: form_builder,
  #     default_locale: :en
  #   )
  #
  # @return [TranslationsFormComponent]
  def initialize(model:, available_locales:, form: nil, default_locale: :en)
    @model = model
    @available_locales = available_locales
    @form = form
    @default_locale = default_locale
  end

  # Get locale configuration for a given locale code
  #
  # @param locale [Symbol] Locale code (e.g., :en, :sv)
  # @return [Hash] Configuration with name and flag
  def locale_config(locale)
    LOCALES[locale] || { name: locale.to_s.upcase, flag: "" }
  end

  # Get translation for a specific locale
  #
  # Returns existing translation or builds a new one if not found.
  #
  # @param locale [Symbol] Locale code
  # @return [Object] Translation object (or new record)
  def translation_for(locale)
    if model.respond_to?(:translations)
      model.translations.find_or_initialize_by(locale: locale.to_s)
    else
      # Fallback if model doesn't support translations
      OpenStruct.new(locale: locale.to_s, name: "", description: "")
    end
  end

  # Check if a locale is the default/active locale
  #
  # @param locale [Symbol] Locale code
  # @return [Boolean]
  def default_locale?(locale)
    locale.to_sym == default_locale.to_sym
  end

  # Generate unique ID for tab panel
  #
  # @param locale [Symbol] Locale code
  # @return [String] Panel ID
  def panel_id(locale)
    "translation-panel-#{locale}"
  end

  # Generate unique ID for tab button
  #
  # @param locale [Symbol] Locale code
  # @return [String] Tab ID
  def tab_id(locale)
    "translation-tab-#{locale}"
  end

  # Get CSS classes for tab button based on state
  #
  # @param locale [Symbol] Locale code
  # @return [String] CSS classes
  def tab_classes(locale)
    base = "px-4 py-2 text-sm font-medium transition-colors duration-150 border-b-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"

    if default_locale?(locale)
      "#{base} border-blue-600 text-blue-600"
    else
      "#{base} border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end
end
