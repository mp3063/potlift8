import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mainImage", "thumbnail"]

  selectImage(event) {
    // Don't select image if clicking on delete button
    if (event.target.closest("button")) {
      return
    }

    const thumbnail = event.currentTarget
    const thumbnailImg = thumbnail.querySelector("img")
    const fullSizeUrl = thumbnail.dataset.fullSizeUrl

    if (!thumbnailImg || !fullSizeUrl) return

    this.mainImageTarget.src = fullSizeUrl
    this.mainImageTarget.alt = thumbnailImg.alt

    this.thumbnailTargets.forEach(thumb => {
      thumb.classList.remove("ring-2", "ring-blue-600", "ring-offset-2")
    })
    thumbnail.classList.add("ring-2", "ring-blue-600", "ring-offset-2")
  }

  deleteImage(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const imageId = button.dataset.imageId

    if (!imageId || !confirm("Are you sure you want to delete this image?")) {
      return
    }

    const csrfToken = document.querySelector("[name='csrf-token']").content
    const productId = this.element.closest("[data-product-id]")?.dataset.productId

    if (!productId) {
      console.error("Product ID not found")
      return
    }

    fetch(`/products/${productId}/images/${imageId}`, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      }
    })
    .then(response => {
      if (response.ok) {
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
