import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Expects DOM structure:
 *   - Container with data-controller="attribute-reorder"
 *   - Lists with data-sortable-group="<group_id>"
 *   - Items with data-attribute-id="<attribute_id>"
 */
export default class extends Controller {
  connect() {
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
      }
    } catch (error) {
      console.error("Reorder error:", error)
    }
  }

  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
}
