# frozen_string_literal: true

# DiffViewComponent - Display attribute value changes with visual diff
#
# Shows before/after comparison of attribute values with color-coded changes.
# Used in version history and audit trail to visualize what changed.
#
# **Change Types:**
# - added: New value (green)
# - removed: Value deleted (red)
# - modified: Value changed (yellow)
# - unchanged: No change (gray)
#
# **Features:**
# - Color-coded backgrounds and borders
# - Side-by-side comparison layout
# - Line-through styling for removed/modified values
# - Bold styling for new values
# - Accessible contrast ratios (WCAG 2.1 AA)
# - Semantic HTML with proper labels
#
# @example Show added value
#   <%= render DiffViewComponent.new(
#     old_value: nil,
#     new_value: "New Product",
#     attribute_name: "name"
#   ) %>
#
# @example Show removed value
#   <%= render DiffViewComponent.new(
#     old_value: "Old Product",
#     new_value: nil,
#     attribute_name: "name"
#   ) %>
#
# @example Show modified value
#   <%= render DiffViewComponent.new(
#     old_value: "19.99",
#     new_value: "24.99",
#     attribute_name: "price"
#   ) %>
#
# @example Show unchanged value
#   <%= render DiffViewComponent.new(
#     old_value: "Active",
#     new_value: "Active",
#     attribute_name: "status"
#   ) %>
#
# @see docs/DESIGN_SYSTEM.md Design System Documentation
#
class DiffViewComponent < ViewComponent::Base
  # Color schemes for different change types
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

  # Initialize a new diff view component
  #
  # @param old_value [String, nil] Previous value (nil if added)
  # @param new_value [String, nil] New value (nil if removed)
  # @param attribute_name [String] Name of the attribute that changed
  #
  # @example
  #   DiffViewComponent.new(
  #     old_value: "Draft",
  #     new_value: "Active",
  #     attribute_name: "status"
  #   )
  #
  # @return [DiffViewComponent]
  def initialize(old_value:, new_value:, attribute_name:)
    @old_value = old_value
    @new_value = new_value
    @attribute_name = attribute_name
    @diff_type = calculate_diff_type
  end

  # Get the style hash for current diff type
  #
  # @return [Hash] Style configuration with bg, border, badge, label
  def style
    CHANGE_STYLES[@diff_type]
  end

  # Check if value was added
  #
  # @return [Boolean]
  def added?
    @diff_type == :added
  end

  # Check if value was removed
  #
  # @return [Boolean]
  def removed?
    @diff_type == :removed
  end

  # Check if value was modified
  #
  # @return [Boolean]
  def modified?
    @diff_type == :modified
  end

  # Check if value is unchanged
  #
  # @return [Boolean]
  def unchanged?
    @diff_type == :unchanged
  end

  # Format attribute name for display (titleize and humanize)
  #
  # @return [String] Human-readable attribute name
  def formatted_attribute_name
    attribute_name.to_s.titleize
  end

  # Display value for rendering (handles nil, empty, and blank values)
  #
  # @param value [String, nil] Value to format
  # @return [String] Formatted value or placeholder
  def display_value(value)
    if value.nil? || value.to_s.strip.empty?
      content_tag(:span, "(empty)", class: "text-gray-400 italic")
    else
      value.to_s
    end
  end

  private

  # Calculate the type of change based on old and new values
  #
  # @return [Symbol] One of :added, :removed, :modified, :unchanged
  def calculate_diff_type
    if old_value.nil? || old_value.to_s.strip.empty?
      # No old value means it was added
      :added
    elsif new_value.nil? || new_value.to_s.strip.empty?
      # No new value means it was removed
      :removed
    elsif old_value.to_s == new_value.to_s
      # Values are the same
      :unchanged
    else
      # Values are different
      :modified
    end
  end
end
