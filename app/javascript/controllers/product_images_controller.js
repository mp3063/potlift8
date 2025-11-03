import { Controller } from "@hotwired/stimulus"

/**
 * Product Images Controller
 *
 * Handles product image gallery interactions:
 * - Click thumbnail to show in main image area
 * - Delete image functionality
 *
 * Targets:
 * - mainImage: The main large image display
 * - thumbnail: Individual thumbnail images
 *
 * @example
 *   <div data-controller="product-images">
 *     <img data-product-images-target="mainImage" src="...">
 *     <div data-product-images-target="thumbnail"
 *          data-action="click->product-images#selectImage">
 *       <img src="...">
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["mainImage", "thumbnail"]

  /**
   * Handle thumbnail click to update main image
   *
   * @param {Event} event - Click event from thumbnail
   */
  selectImage(event) {
    // Don't select image if clicking on delete button
    if (event.target.closest("button")) {
      return
    }

    const thumbnail = event.currentTarget
    const thumbnailImg = thumbnail.querySelector("img")
    const fullSizeUrl = thumbnail.dataset.fullSizeUrl

    if (!thumbnailImg || !fullSizeUrl) return

    // Update main image src to use full-size image (not thumbnail variant)
    this.mainImageTarget.src = fullSizeUrl
    this.mainImageTarget.alt = thumbnailImg.alt

    // Add visual feedback showing selected thumbnail
    this.thumbnailTargets.forEach(thumb => {
      thumb.classList.remove("ring-2", "ring-blue-600", "ring-offset-2")
    })
    thumbnail.classList.add("ring-2", "ring-blue-600", "ring-offset-2")
  }

  /**
   * Handle image deletion
   * Makes DELETE request to remove image
   *
   * @param {Event} event - Click event from delete button
   */
  deleteImage(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const imageId = button.dataset.imageId

    if (!imageId || !confirm("Are you sure you want to delete this image?")) {
      return
    }

    // Get CSRF token
    const csrfToken = document.querySelector("[name='csrf-token']").content
    const productId = this.element.closest("[data-product-id]")?.dataset.productId

    if (!productId) {
      console.error("Product ID not found")
      return
    }

    // Make DELETE request
    fetch(`/products/${productId}/images/${imageId}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      }
    })
    .then(response => {
      if (response.ok) {
        // Reload page to show updated images
        window.location.reload()
      } else {
        alert("Failed to delete image. Please try again.")
      }
    })
    .catch(error => {
      console.error("Error deleting image:", error)
      alert("Failed to delete image. Please try again.")
    })
  }
}
