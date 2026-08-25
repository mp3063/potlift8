import { Controller } from "@hotwired/stimulus"

/**
 * Handles opening/closing modals with proper accessibility:
 * - Escape key to close
 * - Focus trap (focus first focusable element)
 * - Body scroll lock when open
 * - Click outside to close
 * - Prevent close for modal content clicks
 */
export default class extends Controller {
  static targets = ["backdrop", "container"]
  static values = {
    closable: { type: Boolean, default: true }
  }

  connect() {
    this.escHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escHandler)

    if (this.element.closest('turbo-frame[id="modal"]')) {
      this.open()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escHandler)
    document.body.style.overflow = ""
  }

  open(event) {
    if (event) event.preventDefault()

    this.backdropTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    setTimeout(() => {
      const firstFocusable = this.containerTarget.querySelector(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
      if (firstFocusable) firstFocusable.focus()
    }, 100)
  }

  close(event) {
    if (event) event.preventDefault()

    if (!this.closableValue) return

    this.backdropTarget.classList.add("hidden")
    document.body.style.overflow = ""

    const turboFrame = this.element.closest('turbo-frame[id="modal"]')
    if (turboFrame) {
      turboFrame.innerHTML = ""
    }
  }

  handleEscape(event) {
    if (event.key === "Escape" && !this.backdropTarget.classList.contains("hidden")) {
      this.close()
    }
  }

  /**
   * Prevent modal from closing when clicking on modal content
   * This is used on the container to stop event propagation
   */
  preventClose(event) {
    event.stopPropagation()
  }
}
