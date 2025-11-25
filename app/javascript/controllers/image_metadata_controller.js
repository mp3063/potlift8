import { Controller } from "@hotwired/stimulus"

/**
 * Image Metadata Controller
 *
 * Handles metadata editing for product images:
 * - Opens modal with image metadata form
 * - Submits metadata updates via PATCH
 * - Handles form validation and feedback
 *
 * Targets:
 * - modal: The modal container
 * - form: The metadata form
 * - imagePreview: Preview image in modal
 * - altText: Alt text input
 * - caption: Caption input
 * - description: Description textarea
 *
 * Values:
 * - imageId: Current image attachment ID
 * - imageUrl: URL of the image being edited
 * - productId: Product ID for the form submission
 *
 * @example
 *   <div data-controller="image-metadata"
 *        data-image-metadata-product-id-value="123">
 *     <button data-action="click->image-metadata#openModal"
 *             data-image-id="456"
 *             data-image-url="/path/to/image.jpg"
 *             data-alt-text="Current alt"
 *             data-caption="Current caption"
 *             data-description="Current description">
 *       Edit
 *     </button>
 *   </div>
 */
export default class extends Controller {
  static targets = ["modal", "form", "imagePreview", "altText", "caption", "description"]
  static values = {
    imageId: String,
    imageUrl: String,
    productId: String
  }

  /**
   * Open the metadata editing modal
   * Populates form with current metadata from button data attributes
   *
   * @param {Event} event - Click event from edit button
   */
  openModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget

    // Extract data from button attributes
    this.imageIdValue = button.dataset.imageId
    this.imageUrlValue = button.dataset.imageUrl
    const altText = button.dataset.altText || ""
    const caption = button.dataset.caption || ""
    const description = button.dataset.description || ""

    // Populate form fields
    this.altTextTarget.value = altText
    this.captionTarget.value = caption
    this.descriptionTarget.value = description

    // Set image preview
    this.imagePreviewTarget.src = this.imageUrlValue
    this.imagePreviewTarget.alt = altText || "Image preview"

    // Update form action with current image ID
    const formAction = `/products/${this.productIdValue}/images/${this.imageIdValue}`
    this.formTarget.action = formAction

    // Trigger modal open via modal controller
    const modalController = this.application.getControllerForElementAndIdentifier(
      this.modalTarget.closest('[data-controller*="modal"]'),
      "modal"
    )
    if (modalController) {
      modalController.open()
    }
  }

  /**
   * Submit the metadata form
   * Sends PATCH request to update image metadata
   *
   * @param {Event} event - Submit event from form
   */
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
        // Close modal
        const modalController = this.application.getControllerForElementAndIdentifier(
          this.modalTarget.closest('[data-controller*="modal"]'),
          "modal"
        )
        if (modalController) {
          modalController.close()
        }

        // Show success message (flash will be handled by Turbo Stream response)
        // Reload to show updated metadata
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

  /**
   * Cancel editing and close modal
   *
   * @param {Event} event - Click event from cancel button
   */
  cancel(event) {
    event.preventDefault()

    // Trigger modal close via modal controller
    const modalController = this.application.getControllerForElementAndIdentifier(
      this.modalTarget.closest('[data-controller*="modal"]'),
      "modal"
    )
    if (modalController) {
      modalController.close()
    }
  }
}
