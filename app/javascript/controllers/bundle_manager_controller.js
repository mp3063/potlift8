import { Controller } from "@hotwired/stimulus"

/**
 * Bundle Manager Controller
 *
 * Manages bundle product composition, including:
 * - Inline quantity editing
 * - Real-time inventory calculations
 * - Add/remove subproducts
 * - Bundle availability display
 *
 * Values:
 *   - productId: The bundle product ID
 *
 * Actions:
 *   - editQuantity: Enable inline editing for quantity
 *   - saveQuantity: Save quantity change
 *   - cancelEdit: Cancel quantity editing
 *
 * Usage:
 *   <div data-controller="bundle-manager" data-bundle-manager-product-id-value="123">
 *     ...bundle products...
 *   </div>
 *
 * Accessibility:
 * - Keyboard navigation support (Enter to save, Escape to cancel)
 * - Focus management during edit
 * - ARIA labels for edit controls
 * - Screen reader announcements for quantity changes
 */
export default class extends Controller {
  static values = {
    productId: String
  }

  connect() {
    console.log("Bundle Manager connected for product:", this.productIdValue)
  }

  /**
   * Enable inline editing for a bundle product quantity
   *
   * @param {Event} event - Click event
   */
  editQuantity(event) {
    event.preventDefault()

    const quantityDisplay = event.currentTarget.closest('[data-quantity-display]')
    if (!quantityDisplay) return

    const currentQuantity = quantityDisplay.dataset.quantity
    const bundleProductId = quantityDisplay.dataset.bundleProductId

    // Replace display with input
    const input = this.createQuantityInput(currentQuantity, bundleProductId)
    quantityDisplay.replaceWith(input)

    // Focus input and select text
    setTimeout(() => {
      input.querySelector('input').focus()
      input.querySelector('input').select()
    }, 10)
  }

  /**
   * Create quantity input form
   *
   * @param {String} currentQuantity - Current quantity value
   * @param {String} bundleProductId - Bundle product ID
   * @returns {HTMLElement} Form element with input
   */
  createQuantityInput(currentQuantity, bundleProductId) {
    const form = document.createElement('div')
    form.className = 'flex items-center gap-2'
    form.dataset.quantityEditor = ''

    form.innerHTML = `
      <input
        type="number"
        value="${currentQuantity}"
        min="1"
        class="w-20 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
        data-bundle-product-id="${bundleProductId}"
        data-action="
          keydown->bundle-manager#handleKeydown
          blur->bundle-manager#cancelEdit
        "
        aria-label="Quantity"
      >
      <button
        type="button"
        data-action="click->bundle-manager#saveQuantity"
        data-bundle-product-id="${bundleProductId}"
        class="text-green-600 hover:text-green-900"
        aria-label="Save quantity"
      >
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        </svg>
      </button>
      <button
        type="button"
        data-action="click->bundle-manager#cancelEdit"
        data-bundle-product-id="${bundleProductId}"
        class="text-gray-600 hover:text-gray-900"
        aria-label="Cancel editing"
      >
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    `

    return form
  }

  /**
   * Handle keyboard events in quantity input
   *
   * @param {KeyboardEvent} event - Keyboard event
   */
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.saveQuantity(event)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancelEdit(event)
    }
  }

  /**
   * Save quantity change to server
   *
   * @param {Event} event - Click or keyboard event
   */
  async saveQuantity(event) {
    const editor = event.currentTarget.closest('[data-quantity-editor]')
    if (!editor) return

    const input = editor.querySelector('input')
    const newQuantity = input.value
    const bundleProductId = input.dataset.bundleProductId

    if (!newQuantity || newQuantity < 1) {
      this.showError("Quantity must be at least 1")
      input.focus()
      return
    }

    try {
      const response = await fetch(`/products/${this.productIdValue}/bundle_products/${bundleProductId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify({
          bundle_product: { quantity: newQuantity }
        })
      })

      if (response.ok) {
        // Turbo Stream will handle the update
        this.announceQuantityChange(newQuantity)
      } else {
        this.showError("Failed to update quantity")
        this.cancelEdit(event)
      }
    } catch (error) {
      console.error("Save quantity error:", error)
      this.showError("Network error while saving")
      this.cancelEdit(event)
    }
  }

  /**
   * Cancel quantity editing and restore display
   *
   * @param {Event} event - Click or blur event
   */
  cancelEdit(event) {
    // Prevent blur from firing when clicking save/cancel buttons
    if (event.relatedTarget && event.relatedTarget.hasAttribute('data-action')) {
      const action = event.relatedTarget.getAttribute('data-action')
      if (action.includes('saveQuantity') || action.includes('cancelEdit')) {
        return
      }
    }

    const editor = event.currentTarget.closest('[data-quantity-editor]')
    if (!editor) return

    // Reload page to restore state (or use Turbo Frame refresh)
    window.location.reload()
  }

  /**
   * Announce quantity change to screen readers
   *
   * @param {Number} quantity - New quantity value
   */
  announceQuantityChange(quantity) {
    let liveRegion = document.getElementById("bundle-quantity-announcer")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "bundle-quantity-announcer"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.className = "sr-only"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = `Quantity updated to ${quantity}`
  }

  /**
   * Show error notification
   *
   * @param {String} message - Error message
   */
  showError(message) {
    // Could integrate with flash notification system
    alert(message)
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
