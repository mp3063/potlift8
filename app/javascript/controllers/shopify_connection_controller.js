import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "display", "submitButton"]
  static values = {
    editing: { type: Boolean, default: false }
  }

  connect() {
    if (this.hasSubmitButtonTarget) {
      this.originalButtonText = this.submitButtonTarget.textContent
    }
  }

  toggleEdit(event) {
    if (event) event.preventDefault()

    this.editingValue = !this.editingValue

    if (this.editingValue) {
      if (this.hasDisplayTarget) {
        this.displayTarget.classList.add("hidden")
      }
      if (this.hasFormTarget) {
        this.formTarget.classList.remove("hidden")

        setTimeout(() => {
          const firstInput = this.formTarget.querySelector(
            "input:not([type=hidden]), select, textarea"
          )
          if (firstInput) {
            firstInput.focus()
            if (firstInput.tagName === "INPUT" &&
                (firstInput.type === "text" || firstInput.type === "password")) {
              firstInput.select()
            }
          }
        }, 10)
      }
    } else {
      if (this.hasDisplayTarget) {
        this.displayTarget.classList.remove("hidden")
      }
      if (this.hasFormTarget) {
        this.formTarget.classList.add("hidden")
        this.formTarget.reset()
      }

      this.resetSubmitButton()
    }
  }

  /**
   * Handle form submission
   * - Disables submit button to prevent double submission
   * - Changes button text to "Connecting..."
   * - Button state is reset on page reload or toggleEdit
   */
  submit() {
    // Don't prevent default - let the form submit normally
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = "Connecting..."

      this.submitButtonTarget.classList.add("cursor-not-allowed", "opacity-75")
    }
  }

  /**
   * Show confirmation dialog before disconnecting
   * Prevents accidental disconnection from Shopify store
   */
  confirmDisconnect(event) {
    const message = "Are you sure you want to disconnect from this Shopify store? This will stop all synchronization."

    if (!confirm(message)) {
      event.preventDefault()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitButtonTarget && this.originalButtonText) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = this.originalButtonText
      this.submitButtonTarget.classList.remove("cursor-not-allowed", "opacity-75")
    }
  }

  editingValueChanged() {
  }

  disconnect() {
    this.originalButtonText = null
  }
}
