# frozen_string_literal: true

module Products
  # Bulk Label Editor Component
  #
  # Provides a modal interface for adding/removing labels from multiple products at once.
  # Integrates with the bulk_actions_controller.js for product selection.
  #
  # **Features:**
  # - Multi-select label checkboxes
  # - Add labels to selected products
  # - Remove labels from selected products
  # - Clear label selection
  # - Hierarchical label display
  #
  # **Accessibility:**
  # - Semantic form structure
  # - ARIA labels for checkboxes
  # - Keyboard navigation support
  # - Focus indicators
  #
  # **Stimulus Integration:**
  # - Controller: bulk-label-editor
  # - Actions: submit form with selected labels
  #
  # @example Basic usage
  #   <%= render Products::BulkLabelEditorComponent.new(
  #     labels: @available_labels
  #   ) %>
  #
  # @see app/javascript/controllers/bulk_actions_controller.js Bulk Actions Controller
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  #
  class BulkLabelEditorComponent < ViewComponent::Base
    # Initialize a new bulk label editor component
    #
    # @param labels [ActiveRecord::Relation] Collection of available labels
    #
    # @example
    #   BulkLabelEditorComponent.new(
    #     labels: company.labels.root_labels.includes(:sublabels)
    #   )
    #
    # @return [BulkLabelEditorComponent]
    def initialize(labels:)
      @labels = labels
    end

    private

    attr_reader :labels

    # Checkbox icon SVG (checked state)
    def checkbox_checked_icon
      '<svg class="h-5 w-5 text-blue-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Checkbox icon SVG (unchecked state)
    def checkbox_unchecked_icon
      '<svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm0-2a6 6 0 100-12 6 6 0 000 12z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Tag icon SVG
    def tag_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M5.5 3A2.5 2.5 0 003 5.5v2.879a2.5 2.5 0 00.732 1.767l6.5 6.5a2.5 2.5 0 003.536 0l2.878-2.878a2.5 2.5 0 000-3.536l-6.5-6.5A2.5 2.5 0 008.38 3H5.5zM6 7a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
      </svg>'.html_safe
    end
  end
end
