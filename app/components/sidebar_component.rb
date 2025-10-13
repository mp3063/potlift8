# frozen_string_literal: true

# Sidebar navigation component for desktop and mobile layouts
#
# Displays:
# - Company branding (Potlift8 logo)
# - Navigation menu items with active state highlighting
# - Company information at bottom of sidebar
#
# Responsive:
# - Desktop: Fixed sidebar at lg: breakpoint
# - Mobile: Overlay sidebar controlled by mobile_sidebar Stimulus controller
#
# @example Basic usage
#   <%= render SidebarComponent.new(
#     items: navigation_items,
#     active_path: request.path,
#     company: current_potlift_company
#   ) %>
#
class SidebarComponent < ViewComponent::Base
  # Initialize sidebar component
  #
  # @param items [Array<Hash>] Navigation menu items
  #   Each item should have: :name, :path, :icon_path
  # @param active_path [String] Current request path for active state
  # @param company [Company] Current company for display
  def initialize(items:, active_path:, company:)
    @items = items
    @active_path = active_path
    @company = company
  end

  private

  attr_reader :items, :active_path, :company

  # Check if navigation item is currently active
  #
  # @param item [Hash] Navigation item
  # @return [Boolean] true if item path matches current path
  def item_active?(item)
    active_path.start_with?(item[:path])
  end

  # CSS classes for navigation item link
  #
  # @param item [Hash] Navigation item
  # @return [String] Tailwind CSS classes
  def item_classes(item)
    base = "group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6"

    if item_active?(item)
      "#{base} bg-gray-800 text-white"
    else
      "#{base} text-gray-400 hover:text-white hover:bg-gray-800"
    end
  end

  # CSS classes for navigation item icon
  #
  # @param item [Hash] Navigation item
  # @return [String] Tailwind CSS classes
  def icon_classes(item)
    base = "h-6 w-6 shrink-0"

    if item_active?(item)
      "#{base} text-white"
    else
      "#{base} text-gray-400 group-hover:text-white"
    end
  end
end
