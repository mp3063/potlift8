# frozen_string_literal: true

# Displays dismissible flash messages with different styles for:
# - success (green) - Success messages
# - error (red) - Error messages
# - alert (yellow) - Warning messages
# - notice (blue) - Informational messages
class FlashComponent < ViewComponent::Base
  VARIANT_CLASSES = {
    "success" => {
      container: "bg-green-50 border-green-200",
      icon: "text-green-500",
      text: "text-green-800",
      icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>'
    },
    "error" => {
      container: "bg-red-50 border-red-200",
      icon: "text-red-500",
      text: "text-red-800",
      icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>'
    },
    "alert" => {
      container: "bg-yellow-50 border-yellow-200",
      icon: "text-yellow-500",
      text: "text-yellow-800",
      icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>'
    },
    "notice" => {
      container: "bg-blue-50 border-blue-200",
      icon: "text-blue-500",
      text: "text-blue-800",
      icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>'
    }
  }.freeze

  def initialize(flash: nil)
    @flash = flash
  end

  def flash
    @flash || helpers.flash
  end

  private

  def flash_config(type)
    VARIANT_CLASSES[type.to_s] || VARIANT_CLASSES["notice"]
  end
end
