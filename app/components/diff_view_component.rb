# frozen_string_literal: true

class DiffViewComponent < ViewComponent::Base
  CHANGE_STYLES = {
    added: {
      bg: "bg-green-50",
      border: "border-green-200",
      badge: "success",
      label: "Added"
    },
    removed: {
      bg: "bg-red-50",
      border: "border-red-200",
      badge: "danger",
      label: "Removed"
    },
    modified: {
      bg: "bg-yellow-50",
      border: "border-yellow-200",
      badge: "warning",
      label: "Modified"
    },
    unchanged: {
      bg: "bg-gray-50",
      border: "border-gray-200",
      badge: "gray",
      label: "Unchanged"
    }
  }.freeze

  attr_reader :old_value, :new_value, :attribute_name, :diff_type

  def initialize(old_value:, new_value:, attribute_name:)
    @old_value = old_value
    @new_value = new_value
    @attribute_name = attribute_name
    @diff_type = calculate_diff_type
  end

  def style
    CHANGE_STYLES[@diff_type]
  end

  def added?
    @diff_type == :added
  end

  def removed?
    @diff_type == :removed
  end

  def modified?
    @diff_type == :modified
  end

  def unchanged?
    @diff_type == :unchanged
  end

  def formatted_attribute_name
    attribute_name.to_s.titleize
  end

  def display_value(value)
    if value.nil? || value.to_s.strip.empty?
      content_tag(:span, "(empty)", class: "text-gray-400 italic")
    else
      value.to_s
    end
  end

  private

  def calculate_diff_type
    if old_value.nil? || old_value.to_s.strip.empty?
      :added
    elsif new_value.nil? || new_value.to_s.strip.empty?
      :removed
    elsif old_value.to_s == new_value.to_s
      :unchanged
    else
      :modified
    end
  end
end
