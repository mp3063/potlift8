# frozen_string_literal: true

class FilterPanelComponent < ViewComponent::Base
  attr_reader :filters, :available_filters

  def initialize(filters: {}, available_filters: {})
    @filters = filters.to_h.symbolize_keys
    @available_filters = available_filters
  end

  def active_filters
    @active_filters ||= filters.select { |_, v| v.present? && v != "" && v != [] }
  end

  def active_filter_count
    active_filters.count
  end

  def active_filters?
    active_filter_count > 0
  end

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

  def remove_filter_url(key)
    params = helpers.request.params
    params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    new_params = params_hash.except(key.to_s, "action", "controller")
    build_url_with_params(new_params)
  end

  def clear_filters_url
    helpers.request.path
  end

  private

  def build_url_with_params(params)
    path = helpers.request.path
    return path if params.blank?

    query_string = params.to_query
    query_string.present? ? "#{path}?#{query_string}" : path
  end
end
