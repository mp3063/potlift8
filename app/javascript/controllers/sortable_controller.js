import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Sortable Controller
 *
 * Provides drag-and-drop reordering using SortableJS.
 * Sends updated order to server on drop.
 *
 * Usage:
 * <ul data-controller="sortable" data-sortable-url-value="/reorder">
 *   <li data-sortable-id="1">Item 1</li>
 *   <li data-sortable-id="2">Item 2</li>
 * </ul>
 */
export default class extends Controller {
  static values = {
    url: String,
    handle: { type: String, default: "[data-sortable-handle]" },
    animation: { type: Number, default: 150 },
    group: { type: String, default: "" }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: this.animationValue,
      handle: this.hasHandleValue ? this.handleValue : null,
      group: this.groupValue || undefined,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      onEnd: this.handleDrop.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  /**
   * Handle drop event and save new order
   * @param {Event} event - SortableJS end event
   */
  async handleDrop(event) {
    if (!this.hasUrlValue) {
      console.warn("Sortable: No URL value provided, skipping server update")
      return
    }

    // Collect all item IDs in new order
    const items = this.element.querySelectorAll("[data-sortable-id]")
    const assetIds = Array.from(items).map(item => item.dataset.sortableId)

    // Show loading state
    this.element.classList.add("opacity-50", "pointer-events-none")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ asset_ids: assetIds })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      if (data.success) {
        // Optional: Show success feedback
        this.showNotification("Order saved", "success")
      }
    } catch (error) {
      console.error("Sortable: Failed to save order", error)
      this.showNotification("Failed to save order", "error")

      // Revert the change by reloading
      // This is a simple approach; you could also store the original order
      // and restore it manually
    } finally {
      this.element.classList.remove("opacity-50", "pointer-events-none")
    }
  }

  /**
   * Get CSRF token from meta tag
   * @returns {string}
   */
  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.getAttribute("content") : ""
  }

  /**
   * Show a brief notification
   * @param {string} message
   * @param {string} type - "success" or "error"
   */
  showNotification(message, type) {
    // Check if there's a flash container we can use
    const flashContainer = document.getElementById("flash")
    if (flashContainer) {
      const colorClass = type === "success" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"

      const notification = document.createElement("div")
      notification.className = `p-4 rounded-md ${colorClass} mb-4 transition-opacity duration-300`
      notification.textContent = message

      flashContainer.appendChild(notification)

      // Remove after 3 seconds
      setTimeout(() => {
        notification.classList.add("opacity-0")
        setTimeout(() => notification.remove(), 300)
      }, 3000)
    }
  }
}
