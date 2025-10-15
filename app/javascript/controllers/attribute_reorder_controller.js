import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Attribute Reorder Controller
 *
 * Handles drag-and-drop reordering of attributes within groups:
 * - Initializes SortableJS for each attribute group
 * - Sends reorder requests to server
 * - Maintains position state
 *
 * Expects DOM structure:
 *   - Container with data-controller="attribute-reorder"
 *   - Lists with data-sortable-group="<group_id>"
 *   - Items with data-attribute-id="<attribute_id>"
 */
export default class extends Controller {
  connect() {
    // Initialize sortable for each group
    const groups = this.element.querySelectorAll("[data-sortable-group]")

    groups.forEach(group => {
      Sortable.create(group, {
        animation: 150,
        handle: ".cursor-move",
        ghostClass: "bg-blue-50",
        dragClass: "opacity-50",
        onEnd: (event) => {
          this.handleReorder(event, group.dataset.sortableGroup)
        }
      })
    })
  }

  /**
   * Handles reorder event and sends to server
   */
  async handleReorder(event, groupId) {
    const items = event.to.querySelectorAll("[data-attribute-id]")
    const order = Array.from(items).map(item => item.dataset.attributeId)

    try {
      const response = await fetch('/product_attributes/reorder', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          group_id: groupId,
          order: order
        })
      })

      if (!response.ok) {
        console.error("Reorder failed:", response.statusText)
        // Could show error notification here
      }
    } catch (error) {
      console.error("Reorder error:", error)
      // Could show error notification here
    }
  }

  /**
   * Get CSRF token from meta tag
   */
  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
}
