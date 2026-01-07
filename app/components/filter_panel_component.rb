# frozen_string_literal: true

# Advanced filter panel component with active filter chips
#
# Provides a comprehensive filtering interface with:
# - Multiple filter types (select, multi-select, date range)
# - Active filter chips with remove functionality
# - URL state preservation
# - Mobile responsive toggle
# - Filter count badge
# - Turbo Frame integration for live filtering
#
# **Features:**
# - Product type filter (select dropdown)
# - Labels filter (multi-select checkboxes)
# - Status filter (select dropdown)
# - Date range filter (created_from, created_to)
# - Apply and Clear buttons
# - Mobile toggle button
# - Active filter chips with individual remove
# - Clear all filters button
#
# **Accessibility:**
# - Proper label associations
# - ARIA labels for icon buttons
# - Keyboard navigation support
# - Focus management
# - Screen reader friendly
#
# **Stimulus Integration:**
# - Controller: filter-panel
# - Actions: toggleMobile, submit
#
# @example Basic usage in products index
#   <%= render FilterPanelComponent.new(
#     filters: params.slice(:product_type_id, :label_ids, :status, :created_from, :created_to),
#     available_filters: {
#       product_types: ProductType.all,
#       labels: Label.all
#     }
#   ) %>
#
# @see docs/DESIGN_SYSTEM.md Design System Documentation
# @see app/javascript/controllers/filter_panel_controller.js Filter Panel Controller
#
class FilterPanelComponent < ViewComponent::Base
  attr_reader :filters, :available_filters

  # Initialize a new filter panel component
  #
  # @param filters [Hash] Current filter values from params
  # @param available_filters [Hash] Available filter options (product_types, labels, etc.)
  #
  # @example
  #   FilterPanelComponent.new(
  #     filters: { product_type_id: '1', status: 'active' },
  #     available_filters: {
  #       product_types: ProductType.all,
  #       labels: Label.all
  #     }
  #   )
  #
  # @return [FilterPanelComponent]
  def initialize(filters: {}, available_filters: {})
    @filters = filters.to_h.symbolize_keys
    @available_filters = available_filters
  end

  # Get active filters (filters with values)
  #
  # @return [Hash] Active filters hash
  def active_filters
    @active_filters ||= filters.select { |_, v| v.present? && v != "" && v != [] }
  end

  # Get count of active filters
  #
  # @return [Integer] Number of active filters
  def active_filter_count
    active_filters.count
  end

  # Check if any filters are active
  #
  # @return [Boolean] True if any filters are active
  def active_filters?
    active_filter_count > 0
  end

  # Get display name for filter key
  #
  # @param key [Symbol, String] Filter key
  # @return [String] Human-readable filter name
  def filter_display_name(key)
    case key.to_sym
    when :product_type_id
      "Product Type"
    when :label_ids
      "Labels"
    when :status
      "Status"
    when :created_from
      "Created From"
    when :created_to
      "Created To"
    else
      key.to_s.titleize
    end
  end

  # Get display value for filter
  #
  # @param key [Symbol, String] Filter key
  # @param value [Object] Filter value
  # @return [String] Human-readable filter value
  def filter_display_value(key, value)
    case key.to_sym
    when :product_type_id
      available_filters[:product_types]&.find { |pt| pt.id.to_s == value.to_s }&.name || value
    when :label_ids
      return "" if value.blank?
      label_names = Array(value).map do |id|
        available_filters[:labels]&.find { |l| l.id.to_s == id.to_s }&.name
      end.compact
      label_names.join(", ")
    when :status
      value.titleize
    when :created_from, :created_to
      value
    else
      value.to_s
    end
  end

  # Get URL for removing a specific filter
  #
  # @param key [Symbol, String] Filter key to remove
  # @return [String] URL with filter removed
  def remove_filter_url(key)
    params = helpers.request.params
    params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    new_params = params_hash.except(key.to_s, 'action', 'controller')
    build_url_with_params(new_params)
  end

  # Get URL for clearing all filters
  #
  # @return [String] URL with all filters removed
  def clear_filters_url
    helpers.request.path
  end

  private

  # Build URL with query parameters
  #
  # @param params [Hash] Query parameters
  # @return [String] URL with query string
  def build_url_with_params(params)
    path = helpers.request.path
    return path if params.blank?

    query_string = params.to_query
    query_string.present? ? "#{path}?#{query_string}" : path
  end
end
