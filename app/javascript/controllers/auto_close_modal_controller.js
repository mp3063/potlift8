import { Controller } from "@hotwired/stimulus"

// Auto-closes a modal when this controller connects (used from turbo_stream responses).
// Finds the visible modal controller and triggers close, then removes itself.
export default class extends Controller {
  connect() {
    // Find the open modal (the adjust inventory modal)
    const modalEl = document.querySelector('[data-controller~="modal"][data-modal-closable-value="true"]')
    if (modalEl) {
      const modalController = this.application.getControllerForElementAndIdentifier(modalEl, "modal")
      if (modalController) {
        modalController.close()
      }
    }

    // Clean up - remove this element
    this.element.remove()
  }
}
