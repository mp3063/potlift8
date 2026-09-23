import { Controller } from "@hotwired/stimulus"

/**
 * Handles opening/closing modals with proper accessibility:
 * - Escape key to close
 * - Focus trap (focus moves in on open, Tab cycles inside, focus returns to the opener on close)
 * - Body scroll lock when open
 * - Click outside to close
 * - Prevent close for modal content clicks
 */
const FOCUSABLE = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default class extends Controller {
  static targets = ["backdrop", "container"]
  static values = {
    closable: { type: Boolean, default: true }
  }

  connect() {
    this.escHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escHandler)
    this.tabHandler = this.trapTab.bind(this)
    document.addEventListener("keydown", this.tabHandler)

    if (this.element.closest('turbo-frame[id="modal"]')) {
      this.open()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escHandler)
    document.removeEventListener("keydown", this.tabHandler)
    document.body.style.overflow = ""
  }

  open(event) {
    if (event) event.preventDefault()

    this.opener = document.activeElement
    this.backdropTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    setTimeout(() => {
      const firstFocusable = this.containerTarget.querySelector(FOCUSABLE)
      if (firstFocusable) firstFocusable.focus()
    }, 100)
  }

  close(event) {
    if (event) event.preventDefault()

    if (!this.closableValue) return

    this.backdropTarget.classList.add("hidden")
    document.body.style.overflow = ""

    if (this.opener?.isConnected) this.opener.focus()
    this.opener = null

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

  trapTab(event) {
    if (event.key !== "Tab" || this.backdropTarget.classList.contains("hidden")) return

    const focusables = [...this.containerTarget.querySelectorAll(FOCUSABLE)].filter(el => el.offsetParent !== null)
    if (focusables.length === 0) return

    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    const inside = this.containerTarget.contains(document.activeElement)

    if (event.shiftKey && (document.activeElement === first || !inside)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
      event.preventDefault()
      first.focus()
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
