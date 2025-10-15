import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Variant List Controller
 *
 * Handles drag-and-drop reordering of product variants with keyboard accessibility support.
 * Variants can be reordered to control their display order in the variant list.
 *
 * Features:
 * - Drag-and-drop reordering with SortableJS
 * - Keyboard navigation support (Arrow Up/Down, Space/Enter to activate drag)
 * - Visual feedback during drag (ghost class, opacity)
 * - Sends position updates to server
 * - Accessible drag handle with ARIA labels
 *
 * Targets:
 *   - tbody: The table body containing variant rows
 *
 * Usage:
 *   <div data-controller="variant-list">
 *     <tbody data-variant-list-target="tbody">
 *       <tr data-variant-id="123">...</tr>
 *       <tr data-variant-id="456">...</tr>
 *     </tbody>
 *   </div>
 *
 * Accessibility:
 * - Drag handles are keyboard accessible
 * - ARIA live region announces position changes
 * - Focus management during drag operations
 * - Screen reader compatible
 */
export default class extends Controller {
  static targets = ["tbody"]

  connect() {
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  /**
   * Initialize SortableJS for variant reordering
   */
  initializeSortable() {
    if (!this.hasTbodyTarget) return

    this.sortable = Sortable.create(this.tbodyTarget, {
      animation: 150,
      handle: ".cursor-move",
      ghostClass: "bg-blue-50",
      dragClass: "opacity-50",
      forceFallback: true, // Better keyboard support

      // Accessibility: Allow keyboard navigation
      fallbackOnBody: true,
      swapThreshold: 0.65,

      onEnd: (event) => {
        this.handleReorder(event)
      },

      // Keyboard support
      onChoose: (event) => {
        event.item.setAttribute("aria-grabbed", "true")
      },

      onUnchoose: (event) => {
        event.item.setAttribute("aria-grabbed", "false")
      }
    })

    // Add keyboard navigation support
    this.addKeyboardSupport()
  }

  /**
   * Add keyboard navigation for drag-and-drop
   */
  addKeyboardSupport() {
    const rows = this.tbodyTarget.querySelectorAll("tr")

    rows.forEach((row, index) => {
      const handle = row.querySelector(".cursor-move")
      if (!handle) return

      // Make handle keyboard focusable
      handle.setAttribute("tabindex", "0")
      handle.setAttribute("role", "button")
      handle.setAttribute("aria-label", `Reorder variant. Press Space or Enter to grab, Arrow keys to move, Space or Enter to drop.`)

      let grabbed = false

      handle.addEventListener("keydown", (event) => {
        if (event.key === " " || event.key === "Enter") {
          event.preventDefault()
          grabbed = !grabbed

          if (grabbed) {
            row.classList.add("bg-blue-50")
            handle.setAttribute("aria-grabbed", "true")
          } else {
            row.classList.remove("bg-blue-50")
            handle.setAttribute("aria-grabbed", "false")
          }
        } else if (grabbed && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
          event.preventDefault()
          this.moveRow(row, event.key === "ArrowUp" ? -1 : 1)
        } else if (event.key === "Escape" && grabbed) {
          grabbed = false
          row.classList.remove("bg-blue-50")
          handle.setAttribute("aria-grabbed", "false")
        }
      })
    })
  }

  /**
   * Move a row up or down with keyboard
   *
   * @param {HTMLElement} row - The row to move
   * @param {Number} direction - -1 for up, 1 for down
   */
  moveRow(row, direction) {
    const rows = Array.from(this.tbodyTarget.querySelectorAll("tr"))
    const currentIndex = rows.indexOf(row)
    const newIndex = currentIndex + direction

    if (newIndex < 0 || newIndex >= rows.length) return

    if (direction === -1) {
      row.previousElementSibling.before(row)
    } else {
      row.nextElementSibling.after(row)
    }

    // Save new order
    this.saveOrder()

    // Announce to screen readers
    this.announcePosition(newIndex + 1, rows.length)
  }

  /**
   * Handle drag-and-drop reorder event
   *
   * @param {Event} event - SortableJS event
   */
  async handleReorder(event) {
    await this.saveOrder()
  }

  /**
   * Save the current order to the server
   */
  async saveOrder() {
    const rows = this.tbodyTarget.querySelectorAll("tr[data-variant-id]")
    const order = Array.from(rows).map(row => row.dataset.variantId)

    const productId = this.extractProductIdFromUrl()
    if (!productId) {
      console.error("Could not determine product ID for reorder")
      return
    }

    try {
      const response = await fetch(`/products/${productId}/variants/reorder`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ order: order })
      })

      if (!response.ok) {
        console.error("Reorder failed:", response.statusText)
        this.showError("Failed to save variant order")
      }
    } catch (error) {
      console.error("Reorder error:", error)
      this.showError("Network error while saving order")
    }
  }

  /**
   * Extract product ID from current URL
   *
   * @returns {String|null} Product ID or null
   */
  extractProductIdFromUrl() {
    const match = window.location.pathname.match(/\/products\/(\d+)/)
    return match ? match[1] : null
  }

  /**
   * Announce position change to screen readers
   *
   * @param {Number} position - New position (1-based)
   * @param {Number} total - Total number of items
   */
  announcePosition(position, total) {
    let liveRegion = document.getElementById("variant-reorder-announcer")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "variant-reorder-announcer"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.className = "sr-only"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = `Variant moved to position ${position} of ${total}`
  }

  /**
   * Show error notification
   *
   * @param {String} message - Error message
   */
  showError(message) {
    // Could integrate with flash notification system
    console.error(message)
  }

  /**
   * Get CSRF token from meta tag
   *
   * @returns {String} CSRF token
   */
  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
}
