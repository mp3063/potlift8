import { Controller } from "@hotwired/stimulus"

// Manages the sync preview slide-out drawer.
// Opens via Turbo Frame, closes on Esc or backdrop click.
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
