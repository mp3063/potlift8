import { Controller } from "@hotwired/stimulus"

/**
 * Inline Editor Controller
 *
 * Handles inline editing of product attribute values with smooth transitions between
 * display and edit modes. Integrates with Turbo for seamless form submissions.
 *
 * Features:
 * - Toggle between display and edit modes
 * - Auto-focus first input when entering edit mode
 * - Keyboard shortcuts (Escape to cancel, Enter to submit for single inputs)
 * - Turbo integration for seamless updates
 * - Focus management and return
 * - Error handling
 *
 * Targets:
 * - display: Display mode container (shown when not editing)
 * - editor: Edit mode container (shown when editing)
 * - form: Form element for submission
 *
 * Values:
 * - url: Form submission URL
 *
 * @example
 *   <div data-controller="inline-editor" data-inline-editor-url-value="/products/123/attributes/456">
 *     <div data-inline-editor-target="display">
 *       <span>Current Value</span>
 *       <button data-action="click->inline-editor#edit">Edit</button>
 *     </div>
 *     <div data-inline-editor-target="editor" class="hidden">
 *       <form data-inline-editor-target="form"
 *             data-action="turbo:submit-end->inline-editor#handleSubmit">
 *         <input type="text" name="value">
 *         <button type="submit">Save</button>
 *         <button type="button" data-action="click->inline-editor#cancel">Cancel</button>
 *       </form>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["display", "editor", "form"]
  static values = {
    url: String
  }

  /**
   * Store reference to the element that triggered edit mode
   * for focus return on cancel
   */
  connect() {
    this.previousActiveElement = null
  }

  /**
   * Enter edit mode
   * - Hides display mode
   * - Shows editor mode
   * - Focuses first input
   * - Updates ARIA states
   * - Sets up keyboard handlers
   *
   * @param {Event} event - Click event from edit button
   */
  edit(event) {
    event.preventDefault()

    // Store the element that triggered edit for focus return
    this.previousActiveElement = event.target

    // Toggle visibility
    this.displayTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")

    // Update ARIA states
    this.editorTarget.setAttribute("aria-hidden", "false")
    this.displayTarget.setAttribute("aria-hidden", "true")

    // Focus first input/select/textarea
    setTimeout(() => {
      const firstInput = this.editorTarget.querySelector(
        "input:not([type=hidden]), select, textarea"
      )
      if (firstInput) {
        firstInput.focus()

        // Select text in text inputs for easy replacement
        if (firstInput.tagName === "INPUT" &&
            (firstInput.type === "text" || firstInput.type === "number")) {
          firstInput.select()
        }
      }
    }, 10)

    // Set up keyboard handler for Escape key
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }

  /**
   * Cancel edit mode
   * - Returns to display mode
   * - Resets form
   * - Returns focus to edit button
   *
   * @param {Event} event - Click event from cancel button
   */
  cancel(event) {
    if (event) event.preventDefault()

    // Reset form to original values
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }

    // Toggle visibility
    this.editorTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")

    // Update ARIA states
    this.editorTarget.setAttribute("aria-hidden", "true")
    this.displayTarget.setAttribute("aria-hidden", "false")

    // Return focus to the element that triggered edit
    if (this.previousActiveElement) {
      this.previousActiveElement.focus()
      this.previousActiveElement = null
    }

    // Remove keyboard handler
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }
  }

  /**
   * Handle form submission via Turbo
   * Called after Turbo finishes form submission
   *
   * @param {CustomEvent} event - Turbo submit-end event
   */
  handleSubmit(event) {
    const { success, fetchResponse } = event.detail

    if (success) {
      // Successful submission
      // Turbo will update the turbo-frame automatically

      // Return to display mode
      this.editorTarget.classList.add("hidden")
      this.displayTarget.classList.remove("hidden")

      // Update ARIA states
      this.editorTarget.setAttribute("aria-hidden", "true")
      this.displayTarget.setAttribute("aria-hidden", "false")

      // Return focus to the element that triggered edit
      if (this.previousActiveElement) {
        this.previousActiveElement.focus()
        this.previousActiveElement = null
      }

      // Remove keyboard handler
      if (this.escapeHandler) {
        document.removeEventListener("keydown", this.escapeHandler)
        this.escapeHandler = null
      }

      // Show success feedback (subtle flash)
      this.showSuccessFeedback()
    } else {
      // Submission failed - keep editor open and show error
      // Turbo will render error messages in the frame
      this.showErrorFeedback()
    }
  }

  /**
   * Handle Escape key press
   * Cancels edit mode when Escape is pressed
   *
   * @param {KeyboardEvent} event - Keyboard event
   */
  handleEscape(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }

  /**
   * Show subtle success feedback
   * Briefly highlights the updated value
   */
  showSuccessFeedback() {
    // Add success highlight
    this.displayTarget.classList.add("bg-green-50", "ring-2", "ring-green-500", "rounded", "p-1", "-m-1")

    // Announce to screen readers
    this.announceToScreenReader("Attribute value updated successfully")

    // Remove highlight after 1 second
    setTimeout(() => {
      this.displayTarget.classList.remove("bg-green-50", "ring-2", "ring-green-500", "rounded", "p-1", "-m-1")
    }, 1000)
  }

  /**
   * Show error feedback
   * Highlights the editor with error styling
   */
  showErrorFeedback() {
    // Add error highlight to editor
    this.editorTarget.classList.add("ring-2", "ring-red-500", "rounded", "p-2", "-m-2")

    // Announce to screen readers
    this.announceToScreenReader("Failed to update attribute value. Please check the form for errors.")

    // Focus first input with error (if any)
    const errorInput = this.editorTarget.querySelector("input[aria-invalid=true], .field_with_errors input")
    if (errorInput) {
      errorInput.focus()
    }

    // Remove error highlight after 3 seconds
    setTimeout(() => {
      this.editorTarget.classList.remove("ring-2", "ring-red-500", "rounded", "p-2", "-m-2")
    }, 3000)
  }

  /**
   * Announce message to screen readers
   * Creates a live region for accessibility
   *
   * @param {string} message - Message to announce
   */
  announceToScreenReader(message) {
    const announcement = document.createElement("div")
    announcement.setAttribute("role", "status")
    announcement.setAttribute("aria-live", "polite")
    announcement.className = "sr-only"
    announcement.textContent = message

    document.body.appendChild(announcement)

    // Remove after announcement
    setTimeout(() => {
      announcement.remove()
    }, 1000)
  }

  /**
   * Clean up when controller disconnects
   */
  disconnect() {
    // Remove keyboard handler if still attached
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }
  }
}
