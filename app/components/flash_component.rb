# frozen_string_literal: true

# Flash messages component
#
# Displays dismissible flash messages with different styles for:
# - notice (green) - Success messages
# - alert (red) - Error messages
# - warning (yellow) - Warning messages
#
# Features:
# - Auto-dismiss after 5 seconds
# - Manual dismiss button
# - Accessible with ARIA labels
# - Smooth fade-out animation
#
# @example Basic usage in layout
#   <%= render FlashComponent.new %>
#
# @example With explicit flash hash
#   <%= render FlashComponent.new(flash: { notice: 'Success!' }) %>
#
class FlashComponent < ViewComponent::Base
  # Flash message configuration
  FLASH_TYPES = {
    notice: {
      icon: "check-circle",
      bg_color: "bg-green-50",
      text_color: "text-green-800",
      icon_color: "text-green-400"
    },
    alert: {
      icon: "x-circle",
      bg_color: "bg-red-50",
      text_color: "text-red-800",
      icon_color: "text-red-400"
    },
    warning: {
      icon: "exclamation-triangle",
      bg_color: "bg-yellow-50",
      text_color: "text-yellow-800",
      icon_color: "text-yellow-400"
    }
  }.freeze

  # Initialize flash component
  #
  # @param flash [ActionDispatch::Flash::FlashHash] Flash messages (optional, defaults to view's flash)
  def initialize(flash: nil)
    @flash = flash
  end

  # Get flash messages to display
  #
  # @return [ActionDispatch::Flash::FlashHash, Hash] Flash messages
  def flash
    @flash || helpers.flash
  end

  private

  # Get configuration for flash message type
  #
  # @param type [String, Symbol] Flash message type (notice, alert, warning)
  # @return [Hash] Configuration hash with icon, colors
  def flash_config(type)
    FLASH_TYPES[type.to_sym] || FLASH_TYPES[:notice]
  end
end
