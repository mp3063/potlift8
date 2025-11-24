import { Controller } from "@hotwired/stimulus"

/**
 * Modal controller for Ui::ModalComponent
 *
 * Handles opening/closing modals with proper accessibility:
 * - Escape key to close
 * - Focus trap (focus first focusable element)
 * - Body scroll lock when open
 * - Click outside to close
 * - Prevent close for modal content clicks
 *
 * @example
 *   <div data-controller="modal">
 *     <button data-action="click->modal#open">Open Modal</button>
 *     <div data-modal-target="backdrop" class="hidden">
 *       <div data-modal-target="container">
 *         Modal content
 *       </div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["backdrop", "container"]
  static values = {
    closable: { type: Boolean, default: true }
  }

  connect() {
    this.escHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escHandler)

    // Auto-open if this modal is inside a turbo frame (loaded dynamically)
    // When a modal is loaded via turbo_frame_tag "modal", it should auto-open
    if (this.element.closest('turbo-frame[id="modal"]')) {
      this.open()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escHandler)
    document.body.style.overflow = ""
  }

  /**
   * Open the modal
   * - Shows the backdrop
   * - Locks body scroll
   * - Focuses first focusable element
   */
  open(event) {
    if (event) event.preventDefault()

    this.backdropTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    // Focus trap - focus first focusable element
    setTimeout(() => {
      const firstFocusable = this.containerTarget.querySelector(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
      if (firstFocusable) firstFocusable.focus()
    }, 100)
  }

  /**
   * Close the modal
   * - Hides the backdrop
   * - Restores body scroll
   * - Only works if closable value is true
   */
  close(event) {
    if (event) event.preventDefault()

    if (!this.closableValue) return

    this.backdropTarget.classList.add("hidden")
    document.body.style.overflow = ""

    // Clear the turbo frame content so modal can be re-opened
    const turboFrame = this.element.closest('turbo-frame[id="modal"]')
    if (turboFrame) {
      turboFrame.innerHTML = ""
    }
  }

  /**
   * Handle Escape key press
   * Closes modal if it's open and closable
   */
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
