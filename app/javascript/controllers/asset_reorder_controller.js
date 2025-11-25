import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Asset Reorder Controller
 *
 * Enables drag-and-drop reordering of product assets (documents, videos, links)
 * using Sortable.js. Automatically saves the new order to the server via AJAX.
 *
 * Features:
 * - Drag-and-drop reordering with visual feedback
 * - Automatic AJAX save on reorder
 * - Loading state during save
 * - Error handling with user feedback
 * - Position indicator updates
 * - Optional drag handle support
 * - Keyboard accessibility (Sortable.js handles this)
 *
 * Data Attributes:
 * - data-asset-reorder-reorder-url-value: URL to PATCH reorder requests to
 * - data-asset-reorder-handle-value: CSS selector for drag handle (optional)
 * - data-asset-id: ID of each asset in sortable items
 *
 * Targets:
 * - container: The element containing sortable assets
 *
 * Values:
 * - reorderUrl: URL to send reorder requests to (required)
 * - handle: CSS selector for drag handle (optional, defaults to entire item)
 *
 * @example
 *   <div data-controller="asset-reorder"
 *        data-asset-reorder-reorder-url-value="/products/123/assets/reorder"
 *        data-asset-reorder-handle-value=".drag-handle">
 *     <div data-asset-reorder-target="container">
 *       <div data-asset-id="1">
 *         <span class="drag-handle">⋮⋮</span>
 *         Asset 1
 *       </div>
 *       <div data-asset-id="2">
 *         <span class="drag-handle">⋮⋮</span>
 *         Asset 2
 *       </div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["container"]
  static values = {
    reorderUrl: String,
    handle: { type: String, default: null }
  }

  connect() {
    console.log("Asset reorder controller connected")
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
      console.log("Asset reorder controller disconnected")
    }
  }

  /**
   * Initialize Sortable.js on the container
   */
  initializeSortable() {
    if (!this.hasContainerTarget) {
      console.warn("Asset reorder controller: container target not found")
      return
    }

    if (!this.reorderUrlValue) {
      console.error("Asset reorder controller: reorderUrl value is required")
      return
    }

    const options = {
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      chosenClass: "sortable-chosen",
      forceFallback: true, // Better cross-browser support
      fallbackClass: "sortable-fallback",
      onEnd: this.handleReorder.bind(this),
      onStart: this.handleDragStart.bind(this)
    }

    // Add handle if specified
    if (this.handleValue) {
      options.handle = this.handleValue
    }

    this.sortable = Sortable.create(this.containerTarget, options)

    console.log("Sortable initialized with options:", options)
  }

  /**
   * Handle drag start event
   * @param {Object} event - Sortable.js event object
   */
  handleDragStart(event) {
    // Add visual feedback
    event.item.classList.add("opacity-50")
  }

  /**
   * Handle reorder event from Sortable.js
   * Sends new order to server via AJAX
   *
   * @param {Object} event - Sortable.js event object
   */
  handleReorder(event) {
    // Remove drag visual feedback
    event.item.classList.remove("opacity-50")

    // Get asset IDs in new order
    const assetIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.assetId)
      .filter(id => id) // Remove any undefined/null values

    if (assetIds.length === 0) {
      console.warn("No asset IDs found for reordering")
      return
    }

    console.log("Reordering assets:", assetIds)

    // Show loading state
    this.showLoadingState()

    // Get CSRF token
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      this.showErrorState("Failed to reorder assets. Please refresh and try again.")
      return
    }

    // Send AJAX request to reorder
    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ asset_ids: assetIds })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log("Reorder successful:", data)
      this.showSuccessState(data.message || "Assets reordered successfully")
      this.updatePositionIndicators()
    })
    .catch(error => {
      console.error("Error reordering assets:", error)
      this.showErrorState("Failed to reorder assets. Please try again.")

      // Optionally reload page to reset order
      // Uncomment if you want to reset on error:
      // setTimeout(() => window.location.reload(), 2000)
    })
  }

  /**
   * Update position indicators after reorder
   * Updates any elements with .position-indicator class
   */
  updatePositionIndicators() {
    const indicators = this.containerTarget.querySelectorAll(".position-indicator")
    indicators.forEach((indicator, index) => {
      indicator.textContent = index + 1
    })

    // Also update any data-position attributes
    const items = this.containerTarget.children
    Array.from(items).forEach((item, index) => {
      item.dataset.position = index + 1
    })
  }

  /**
   * Show loading state
   */
  showLoadingState() {
    this.containerTarget.classList.add("opacity-50", "pointer-events-none")
    this.containerTarget.setAttribute("aria-busy", "true")

    // Disable sortable during save
    if (this.sortable) {
      this.sortable.option("disabled", true)
    }
  }

  /**
   * Hide loading state
   */
  hideLoadingState() {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")
    this.containerTarget.setAttribute("aria-busy", "false")

    // Re-enable sortable after save
    if (this.sortable) {
      this.sortable.option("disabled", false)
    }
  }

  /**
   * Show success state
   * @param {String} message - Success message
   */
  showSuccessState(message) {
    this.hideLoadingState()
    this.showFlashMessage(message, "success")
  }

  /**
   * Show error state
   * @param {String} message - Error message
   */
  showErrorState(message) {
    this.hideLoadingState()
    this.showFlashMessage(message, "error")
  }

  /**
   * Show flash message
   * @param {String} message - Message to display
   * @param {String} type - Message type (success, error)
   */
  showFlashMessage(message, type) {
    // Check if flash container exists
    const flashContainer = document.getElementById("flash-messages")

    if (flashContainer) {
      // Create flash message element
      const flashElement = document.createElement("div")
      flashElement.className = `flash-message flash-${type} mb-4 p-4 rounded-lg ${
        type === "success" ? "bg-green-50 text-green-800 border border-green-200" : "bg-red-50 text-red-800 border border-red-200"
      }`
      flashElement.setAttribute("role", type === "error" ? "alert" : "status")
      flashElement.setAttribute("aria-live", type === "error" ? "assertive" : "polite")

      flashElement.innerHTML = `
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${type === "success" ? `
              <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
              </svg>
            ` : `
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
              </svg>
            `}
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium">${this.escapeHtml(message)}</p>
          </div>
          <div class="ml-auto pl-3">
            <button type="button" class="inline-flex rounded-md p-1.5 ${
              type === "success" ? "text-green-500 hover:bg-green-100 focus:ring-green-600" : "text-red-500 hover:bg-red-100 focus:ring-red-600"
            } focus:outline-none focus:ring-2 focus:ring-offset-2" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      // Clear existing messages
      flashContainer.innerHTML = ""
      flashContainer.appendChild(flashElement)

      // Add dismiss handler
      const dismissButton = flashElement.querySelector("button")
      dismissButton.addEventListener("click", () => {
        flashElement.remove()
      })

      // Auto-dismiss after 3 seconds
      setTimeout(() => {
        if (flashElement.parentNode) {
          flashElement.remove()
        }
      }, 3000)
    } else {
      // Fallback to fixed position flash message
      const flashElement = document.createElement("div")
      flashElement.className = `fixed top-20 right-4 z-50 max-w-sm rounded-md p-4 shadow-lg ${
        type === "success" ? "bg-green-50 border border-green-200" : "bg-red-50 border border-red-200"
      }`
      flashElement.setAttribute("role", type === "error" ? "alert" : "status")
      flashElement.setAttribute("aria-live", type === "error" ? "assertive" : "polite")

      flashElement.innerHTML = `
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${type === "success" ? `
              <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
              </svg>
            ` : `
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
              </svg>
            `}
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium ${type === "success" ? "text-green-800" : "text-red-800"}">
              ${this.escapeHtml(message)}
            </p>
          </div>
          <div class="ml-auto pl-3">
            <button type="button" class="inline-flex rounded-md p-1.5 ${
              type === "success" ? "text-green-500 hover:bg-green-100 focus:ring-green-600" : "text-red-500 hover:bg-red-100 focus:ring-red-600"
            } focus:outline-none focus:ring-2 focus:ring-offset-2" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      document.body.appendChild(flashElement)

      // Add dismiss handler
      const dismissButton = flashElement.querySelector("button")
      dismissButton.addEventListener("click", () => {
        flashElement.remove()
      })

      // Auto-dismiss after 3 seconds
      setTimeout(() => {
        if (flashElement.parentNode) {
          flashElement.remove()
        }
      }, 3000)
    }
  }

  /**
   * Escape HTML to prevent XSS
   *
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
