import { Controller } from "@hotwired/stimulus"

/**
 * Shopify Connection Controller
 *
 * Manages the UX for Shopify store connection settings:
 * - Toggle between display and edit modes for credentials
 * - Loading states during form submission
 * - Confirmation dialog before disconnecting
 *
 * Targets:
 * - form: The credentials form element
 * - display: The connected state display (shown when not editing)
 * - submitButton: The submit button for loading state management
 *
 * Values:
 * - editing (Boolean): Whether currently in edit mode
 *
 * Actions:
 * - toggleEdit: Switches between display and edit modes
 * - submit: Shows loading state on submit button
 * - confirmDisconnect: Shows confirmation dialog before disconnect
 *
 * @example
 *   <div data-controller="shopify-connection" data-shopify-connection-editing-value="false">
 *     <div data-shopify-connection-target="display">
 *       <!-- Connected state display -->
 *       <button data-action="click->shopify-connection#toggleEdit">Edit</button>
 *       <button data-action="click->shopify-connection#confirmDisconnect">Disconnect</button>
 *     </div>
 *     <form data-shopify-connection-target="form" class="hidden"
 *           data-action="submit->shopify-connection#submit">
 *       <!-- Credentials form fields -->
 *       <button type="submit" data-shopify-connection-target="submitButton">Connect</button>
 *       <button type="button" data-action="click->shopify-connection#toggleEdit">Cancel</button>
 *     </form>
 *   </div>
 */
export default class extends Controller {
  static targets = ["form", "display", "submitButton"]
  static values = {
    editing: { type: Boolean, default: false }
  }

  /**
   * Initialize controller
   * Store original button text for restoration
   */
  connect() {
    if (this.hasSubmitButtonTarget) {
      this.originalButtonText = this.submitButtonTarget.textContent
    }
  }

  /**
   * Toggle between display and edit modes
   * - When entering edit mode: hides display, shows form, focuses first input
   * - When leaving edit mode: shows display, hides form, resets form
   *
   * @param {Event} event - Click event from toggle button
   */
  toggleEdit(event) {
    if (event) event.preventDefault()

    this.editingValue = !this.editingValue

    if (this.editingValue) {
      // Entering edit mode
      if (this.hasDisplayTarget) {
        this.displayTarget.classList.add("hidden")
      }
      if (this.hasFormTarget) {
        this.formTarget.classList.remove("hidden")

        // Focus first input after transition
        setTimeout(() => {
          const firstInput = this.formTarget.querySelector(
            "input:not([type=hidden]), select, textarea"
          )
          if (firstInput) {
            firstInput.focus()
            // Select text in text inputs for easy replacement
            if (firstInput.tagName === "INPUT" &&
                (firstInput.type === "text" || firstInput.type === "password")) {
              firstInput.select()
            }
          }
        }, 10)
      }
    } else {
      // Leaving edit mode
      if (this.hasDisplayTarget) {
        this.displayTarget.classList.remove("hidden")
      }
      if (this.hasFormTarget) {
        this.formTarget.classList.add("hidden")
        this.formTarget.reset()
      }

      // Reset submit button state
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

      // Add visual loading indicator
      this.submitButtonTarget.classList.add("cursor-not-allowed", "opacity-75")
    }
  }

  /**
   * Show confirmation dialog before disconnecting
   * Prevents accidental disconnection from Shopify store
   *
   * @param {Event} event - Click event from disconnect button
   */
  confirmDisconnect(event) {
    const message = "Are you sure you want to disconnect from this Shopify store? This will stop all synchronization."

    if (!confirm(message)) {
      event.preventDefault()
    }
  }

  /**
   * Reset submit button to original state
   * Called when canceling edit mode or after errors
   */
  resetSubmitButton() {
    if (this.hasSubmitButtonTarget && this.originalButtonText) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = this.originalButtonText
      this.submitButtonTarget.classList.remove("cursor-not-allowed", "opacity-75")
    }
  }

  /**
   * Handle editing value change
   * Callback when editingValue changes via Stimulus value system
   */
  editingValueChanged() {
    // Value tracking for external use or debugging
    // The actual UI updates are handled in toggleEdit()
  }

  /**
   * Clean up when controller disconnects
   */
  disconnect() {
    this.originalButtonText = null
  }
}
