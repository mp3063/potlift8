# frozen_string_literal: true

class SidebarComponent < ViewComponent::Base
  def initialize(items:, active_path:, company:)
    @items = items
    @active_path = active_path
    @company = company
  end

  private

  attr_reader :items, :active_path, :company

  def item_active?(item)
    active_path.start_with?(item[:path])
  end

  def item_classes(item)
    base = "group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6"

    if item_active?(item)
      "#{base} bg-gray-800 text-white"
    else
      "#{base} text-gray-400 hover:text-white hover:bg-gray-800"
    end
  end

  def icon_classes(item)
    base = "h-6 w-6 shrink-0"

    if item_active?(item)
      "#{base} text-white"
    else
      "#{base} text-gray-400 group-hover:text-white"
    end
  end
end
