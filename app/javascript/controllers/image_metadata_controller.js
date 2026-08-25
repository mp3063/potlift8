import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "imagePreview", "altText", "caption", "description"]
  static values = {
    imageId: String,
    imageUrl: String,
    productId: String
  }

  openModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget

    this.imageIdValue = button.dataset.imageId
    this.imageUrlValue = button.dataset.imageUrl
    const altText = button.dataset.altText || ""
    const caption = button.dataset.caption || ""
    const description = button.dataset.description || ""

    this.altTextTarget.value = altText
    this.captionTarget.value = caption
    this.descriptionTarget.value = description

    this.imagePreviewTarget.src = this.imageUrlValue
    this.imagePreviewTarget.alt = altText || "Image preview"

    const formAction = `/products/${this.productIdValue}/images/${this.imageIdValue}`
    this.formTarget.action = formAction

    const modalController = this.application.getControllerForElementAndIdentifier(
      this.modalTarget.closest('[data-controller*="modal"]'),
      "modal"
    )
    if (modalController) {
      modalController.open()
    }
  }

  async submitForm(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const csrfToken = document.querySelector("[name='csrf-token']").content

    try {
      const response = await fetch(this.formTarget.action, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: formData
      })

      if (response.ok) {
        const modalController = this.application.getControllerForElementAndIdentifier(
          this.modalTarget.closest('[data-controller*="modal"]'),
          "modal"
        )
        if (modalController) {
          modalController.close()
        }

        window.location.reload()
      } else {
        const errorData = await response.json()
        alert(`Failed to update metadata: ${errorData.error || 'Unknown error'}`)
      }
    } catch (error) {
      console.error("Error updating image metadata:", error)
      alert("Failed to update metadata. Please try again.")
    }
  }

  cancel(event) {
    event.preventDefault()

    const modalController = this.application.getControllerForElementAndIdentifier(
      this.modalTarget.closest('[data-controller*="modal"]'),
      "modal"
    )
    if (modalController) {
      modalController.close()
    }
  }
}
