import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

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

  initializeSortable() {
    if (!this.hasContainerTarget) {
      console.warn("Image reorder controller: container target not found")
      return
    }

    this.sortable = Sortable.create(this.containerTarget, {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      onEnd: this.handleReorder.bind(this)
    })
  }

  setPrimary(event) {
    event.preventDefault()
    event.stopPropagation()

    const imageId = event.currentTarget.dataset.imageId

    if (!imageId) {
      console.error("Image ID not found")
      return
    }

    const currentImageIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.imageId)
      .filter(id => id)

    const imageIndex = currentImageIds.indexOf(imageId)

    if (imageIndex === -1) {
      console.error("Image not found in current order")
      return
    }

    if (imageIndex === 0) {
      // Already primary, do nothing
      return
    }

    const newImageIds = [
      imageId,
      ...currentImageIds.filter(id => id !== imageId)
    ]

    this.sendReorderRequest(newImageIds, "Image set as primary successfully")
  }

  handleReorder(event) {
    const imageIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.imageId)
      .filter(id => id)

    if (imageIds.length === 0) {
      console.warn("No image IDs found for reordering")
      return
    }

    this.sendReorderRequest(imageIds, "Images reordered successfully")
  }

  sendReorderRequest(imageIds, successMessage) {
    this.showLoadingState()

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      this.showErrorState("Failed to reorder images. Please refresh and try again.")
      return
    }

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
      Turbo.renderStreamMessage(html)
      this.showSuccessState(successMessage || "Images reordered successfully")
    })
    .catch(error => {
      console.error("Error reordering images:", error)
      this.showErrorState("Failed to reorder images. Please try again.")
    })
  }

  updatePositionIndicators() {
    const indicators = this.containerTarget.querySelectorAll(".position-indicator")
    indicators.forEach((indicator, index) => {
      indicator.textContent = index + 1
    })
  }

  showLoadingState() {
    this.containerTarget.classList.add("opacity-50", "pointer-events-none")
  }

  showSuccessState(message) {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")

    this.showFlashMessage(message, "success")
  }

  showErrorState(message) {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")

    this.showFlashMessage(message, "error")
  }

  showFlashMessage(message, type) {
    const flashContainer = document.getElementById("flash-messages")

    if (flashContainer) {
      const flashElement = document.createElement("div")
      flashElement.className = `flash-message flash-${type} mb-4 p-4 rounded-lg ${
        type === "success" ? "bg-green-50 text-green-800" : "bg-red-50 text-red-800"
      }`
      flashElement.textContent = message

      flashContainer.innerHTML = ""
      flashContainer.appendChild(flashElement)

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
