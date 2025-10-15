# frozen_string_literal: true

module Products
  # Product activity timeline component for sidebar
  #
  # Displays recent activity list in timeline-style format with icon indicators
  # and timestamps. Currently shows placeholder content, designed for integration
  # with audit/activity log system (e.g., PaperTrail, Audited).
  #
  # @example Render activity timeline
  #   <%= render Products::ActivityTimelineComponent.new(product: @product) %>
  #
  class ActivityTimelineComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new activity timeline component
    #
    # @param product [Product] Product instance
    # @return [ActivityTimelineComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns recent activities for the product
    #
    # TODO: This would come from an audit/activity log system like PaperTrail
    # Currently returns placeholder activities for UI demonstration
    #
    # @return [Array<Hash>] Array of activity hashes with type, description, timestamp
    def recent_activities
      # Placeholder activities - replace with actual audit log when implemented
      [
        {
          type: :update,
          description: "Product updated",
          timestamp: product.updated_at,
          user: "System"
        },
        {
          type: :create,
          description: "Product created",
          timestamp: product.created_at,
          user: "System"
        }
      ]
    end

    # Returns icon SVG path for activity type
    #
    # @param type [Symbol] Activity type (:create, :update, :delete, :status_change)
    # @return [String] SVG path data
    def activity_icon_path(type)
      case type
      when :create
        "M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
      when :update
        "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"
      when :delete
        "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
      when :status_change
        "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      else
        "M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
      end
    end

    # Returns color class for activity type
    #
    # @param type [Symbol] Activity type
    # @return [String] Tailwind color class
    def activity_color(type)
      case type
      when :create
        "text-green-500"
      when :update
        "text-blue-500"
      when :delete
        "text-red-500"
      when :status_change
        "text-yellow-500"
      else
        "text-gray-500"
      end
    end

    # Checks if any activities exist
    #
    # @return [Boolean] True if activities present
    def has_activities?
      recent_activities.any?
    end
  end
end
