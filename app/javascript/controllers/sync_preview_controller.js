import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.body.classList.add("overflow-hidden")
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.replaceChildren()
    } else {
      this.element.remove()
    }
    document.body.classList.remove("overflow-hidden")
  }
}
