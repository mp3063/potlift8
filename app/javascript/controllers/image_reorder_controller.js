import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Image Reorder Controller
 *
 * Enables drag-and-drop reordering of product images using Sortable.js.
 * Automatically saves the new order to the server via AJAX.
 *
 * Data Attributes:
 * - data-image-reorder-reorder-url-value: URL to POST reorder requests to
 *
 * Targets:
 * - container: The element containing sortable images
 *
 * @example
 *   <div data-controller="image-reorder"
 *        data-image-reorder-reorder-url-value="/products/123/images/reorder">
 *     <div data-image-reorder-target="container">
 *       <div data-image-id="1">Image 1</div>
 *       <div data-image-id="2">Image 2</div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["container"]
  static values = {
    reorderUrl: String
  }

  connect() {
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  /**
   * Initialize Sortable.js on the container
   */
  initializeSortable() {
    if (!this.hasContainerTarget) {
      console.warn("Image reorder controller: container target not found")
      return
    }

    this.sortable = Sortable.create(this.containerTarget, {
      animation: 150,
      handle: ".drag-handle", // Optional: only drag from specific handle
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      onEnd: this.handleReorder.bind(this)
    })
  }

  /**
   * Set an image as primary by moving it to position 1
   * Called when clicking the "Set as Primary" button
   *
   * @param {Event} event - Click event
   */
  setPrimary(event) {
    event.preventDefault()
    event.stopPropagation()

    const imageId = event.currentTarget.dataset.imageId

    if (!imageId) {
      console.error("Image ID not found")
      return
    }

    // Get all image IDs in current order
    const currentImageIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.imageId)
      .filter(id => id)

    // Find index of clicked image
    const imageIndex = currentImageIds.indexOf(imageId)

    if (imageIndex === -1) {
      console.error("Image not found in current order")
      return
    }

    if (imageIndex === 0) {
      // Already primary, do nothing
      return
    }

    // Move the selected image to position 0 (first)
    // Create new order: [selectedId, ...otherIds]
    const newImageIds = [
      imageId,
      ...currentImageIds.filter(id => id !== imageId)
    ]

    // Send reorder request
    this.sendReorderRequest(newImageIds, "Image set as primary successfully")
  }

  /**
   * Handle reorder event from Sortable.js
   * Sends new order to server via AJAX
   *
   * @param {Object} event - Sortable.js event object
   */
  handleReorder(event) {
    // Get image IDs in new order
    const imageIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.imageId)
      .filter(id => id) // Remove any undefined/null values

    if (imageIds.length === 0) {
      console.warn("No image IDs found for reordering")
      return
    }

    // Send reorder request
    this.sendReorderRequest(imageIds, "Images reordered successfully")
  }

  /**
   * Send reorder request to server
   *
   * @param {Array} imageIds - Array of image IDs in new order
   * @param {String} successMessage - Message to display on success
   */
  sendReorderRequest(imageIds, successMessage) {
    // Show loading state
    this.showLoadingState()

    // Get CSRF token
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      this.showErrorState("Failed to reorder images. Please refresh and try again.")
      return
    }

    // Send AJAX request to reorder using Turbo Streams
    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ image_ids: imageIds })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.text()
    })
    .then(html => {
      // Turbo will automatically process the Turbo Stream response
      // and update the DOM
      Turbo.renderStreamMessage(html)
      this.showSuccessState(successMessage || "Images reordered successfully")
    })
    .catch(error => {
      console.error("Error reordering images:", error)
      this.showErrorState("Failed to reorder images. Please try again.")
    })
  }

  /**
   * Update position indicators after reorder
   */
  updatePositionIndicators() {
    const indicators = this.containerTarget.querySelectorAll(".position-indicator")
    indicators.forEach((indicator, index) => {
      indicator.textContent = index + 1
    })
  }

  /**
   * Show loading state
   */
  showLoadingState() {
    this.containerTarget.classList.add("opacity-50", "pointer-events-none")
  }

  /**
   * Show success state
   * @param {String} message - Success message
   */
  showSuccessState(message) {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")

    // Show flash message if flash component exists
    this.showFlashMessage(message, "success")
  }

  /**
   * Show error state
   * @param {String} message - Error message
   */
  showErrorState(message) {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")

    // Show flash message if flash component exists
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
        type === "success" ? "bg-green-50 text-green-800" : "bg-red-50 text-red-800"
      }`
      flashElement.textContent = message

      // Add to container
      flashContainer.innerHTML = ""
      flashContainer.appendChild(flashElement)

      // Auto-dismiss after 3 seconds
      setTimeout(() => {
        flashElement.remove()
      }, 3000)
    } else {
      // Fallback to alert if no flash container
      if (type === "error") {
        alert(message)
      }
    }
  }
}
