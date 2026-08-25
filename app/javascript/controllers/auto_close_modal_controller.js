import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const modalEl = document.querySelector('[data-controller~="modal"][data-modal-closable-value="true"]')
    if (modalEl) {
      const modalController = this.application.getControllerForElementAndIdentifier(modalEl, "modal")
      if (modalController) {
        modalController.close()
      }
    }

    this.element.remove()
  }
}
