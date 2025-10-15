import { Controller } from "@hotwired/stimulus"

/**
 * Product Labels Controller
 *
 * Manages product label assignment and removal with smooth UI updates.
 * Handles label removal via API with optimistic UI updates and error rollback.
 *
 * Features:
 * - Remove labels with confirmation
 * - Optimistic UI updates (immediate removal from DOM)
 * - Error rollback (restore label if removal fails)
 * - CSRF token handling
 * - Accessibility announcements
 * - Error flash messages
 *
 * Targets:
 * - container: Container holding label elements
 *
 * Values:
 * - productId: Product ID for API calls
 *
 * @example
 *   <div data-controller="product-labels" data-product-labels-product-id-value="123">
 *     <div data-product-labels-target="container">
 *       <span data-label-id="456">
 *         Label Name
 *         <button data-action="click->product-labels#removeLabel"
 *                 data-label-id="456">Remove</button>
 *       </span>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["container"]
  static values = {
    productId: String
  }

  /**
   * Initialize controller
   * Sets up any necessary state
   */
  connect() {
    // Cache for removed labels (for rollback on error)
    this.removedLabels = new Map()
  }

  /**
   * Remove a label from the product
   * Uses optimistic UI update with rollback on error
   *
   * @param {Event} event - Click event from remove button
   */
  async removeLabel(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const labelElement = button.closest("span[data-label-id]")

    if (!labelElement) {
      console.error("Could not find label element")
      return
    }

    const labelId = labelElement.dataset.labelId
    const labelName = labelElement.textContent.trim()

    // Store label HTML for potential rollback
    this.removedLabels.set(labelId, {
      html: labelElement.outerHTML,
      name: labelName
    })

    // Optimistic UI update - remove immediately
    labelElement.style.transition = "opacity 150ms ease-out"
    labelElement.style.opacity = "0"

    setTimeout(() => {
      labelElement.remove()
      this.announceToScreenReader(`Label ${labelName} removed`)
    }, 150)

    // Make API call to remove label
    try {
      const response = await fetch(`/products/${this.productIdValue}/remove_label`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ label_id: labelId })
      })

      if (!response.ok) {
        // Rollback on error
        await this.rollbackLabelRemoval(labelId)

        const errorData = await response.json().catch(() => ({}))
        const errorMessage = errorData.error || "Failed to remove label. Please try again."
        this.showError(errorMessage)
      } else {
        // Success - clean up stored data
        this.removedLabels.delete(labelId)
      }
    } catch (error) {
      // Network error - rollback
      console.error("Error removing label:", error)
      await this.rollbackLabelRemoval(labelId)
      this.showError("Network error. Please check your connection and try again.")
    }
  }

  /**
   * Rollback label removal by re-adding it to the DOM
   * Called when removal fails
   *
   * @param {string} labelId - ID of label to rollback
   */
  async rollbackLabelRemoval(labelId) {
    const labelData = this.removedLabels.get(labelId)

    if (labelData) {
      // Re-add label to container
      this.containerTarget.insertAdjacentHTML("beforeend", labelData.html)

      // Announce rollback to screen readers
      this.announceToScreenReader(`Failed to remove label ${labelData.name}. Label restored.`)

      // Clean up stored data
      this.removedLabels.delete(labelId)
    }
  }

  /**
   * Show error message to user
   * Creates a flash-style error message
   *
   * @param {string} message - Error message to display
   */
  showError(message) {
    const errorDiv = document.createElement("div")
    errorDiv.className = "fixed top-20 right-4 z-50 max-w-sm rounded-md bg-red-50 p-4 shadow-lg"
    errorDiv.setAttribute("role", "alert")
    errorDiv.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium text-red-800">${this.escapeHtml(message)}</p>
        </div>
        <div class="ml-auto pl-3">
          <button type="button"
                  class="inline-flex rounded-md bg-red-50 p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50"
                  aria-label="Dismiss error">
            <span class="sr-only">Dismiss</span>
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
      </div>
    `

    document.body.appendChild(errorDiv)

    // Add dismiss handler
    const dismissButton = errorDiv.querySelector("button")
    dismissButton.addEventListener("click", () => {
      errorDiv.style.transition = "opacity 150ms ease-out"
      errorDiv.style.opacity = "0"
      setTimeout(() => errorDiv.remove(), 150)
    })

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      if (errorDiv.parentNode) {
        errorDiv.style.transition = "opacity 150ms ease-out"
        errorDiv.style.opacity = "0"
        setTimeout(() => errorDiv.remove(), 150)
      }
    }, 5000)
  }

  /**
   * Announce message to screen readers
   * Creates a live region for accessibility
   *
   * @param {string} message - Message to announce
   */
  announceToScreenReader(message) {
    const announcement = document.createElement("div")
    announcement.setAttribute("role", "status")
    announcement.setAttribute("aria-live", "polite")
    announcement.className = "sr-only"
    announcement.textContent = message

    document.body.appendChild(announcement)

    // Remove after announcement
    setTimeout(() => {
      announcement.remove()
    }, 1000)
  }

  /**
   * Get CSRF token from meta tag
   * Required for Rails form submissions
   *
   * @returns {string} CSRF token
   */
  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ""
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

  /**
   * Clean up when controller disconnects
   */
  disconnect() {
    // Clear any stored removed labels
    this.removedLabels.clear()
  }
}
