import { Controller } from "@hotwired/stimulus"

/**
 * Label Selector Controller
 *
 * Manages the label selection dropdown for adding labels to products.
 * Resets the select dropdown after successful label addition via Turbo Stream.
 *
 * Features:
 * - Handle form submission via Turbo
 * - Reset select dropdown after successful addition
 * - Clear selection and return to prompt
 * - Integrate with Turbo Stream responses
 * - Accessibility support
 *
 * Targets:
 * - select: Select dropdown element
 *
 * @example
 *   <form data-controller="label-selector"
 *         data-action="turbo:submit-end->label-selector#handleSubmit">
 *     <select data-label-selector-target="select">
 *       <option value="">Select a label...</option>
 *       <option value="1">Label 1</option>
 *       <option value="2">Label 2</option>
 *     </select>
 *     <button type="submit">Add</button>
 *   </form>
 */
export default class extends Controller {
  static targets = ["select"]

  /**
   * Handle form submission via Turbo
   * Resets select dropdown on successful submission
   *
   * @param {CustomEvent} event - Turbo submit-end event
   */
  handleSubmit(event) {
    const { success, fetchResponse } = event.detail

    if (success) {
      // Successful submission
      // Turbo Stream will update the labels container automatically

      // Reset select dropdown to prompt option
      this.resetSelect()

      // Announce success to screen readers
      this.announceToScreenReader("Label added successfully")

      // Focus back to select for easy next selection
      setTimeout(() => {
        if (this.hasSelectTarget) {
          this.selectTarget.focus()
        }
      }, 100)
    } else {
      // Submission failed
      // Show error feedback
      this.showError()

      // Announce error to screen readers
      this.announceToScreenReader("Failed to add label. Please try again.")
    }
  }

  /**
   * Reset select dropdown to prompt option
   * Clears current selection
   */
  resetSelect() {
    if (this.hasSelectTarget) {
      // Reset to first option (prompt)
      this.selectTarget.selectedIndex = 0

      // Trigger change event for any listeners
      this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))

      // Remove any error styling
      this.selectTarget.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
      this.selectTarget.classList.add("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
    }
  }

  /**
   * Show error feedback on select dropdown
   * Adds error styling and highlights the field
   */
  showError() {
    if (this.hasSelectTarget) {
      // Add error styling using blue theme (NOT indigo)
      this.selectTarget.classList.remove("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
      this.selectTarget.classList.add("border-red-300", "focus:border-red-500", "focus:ring-red-500")

      // Add aria-invalid for accessibility
      this.selectTarget.setAttribute("aria-invalid", "true")

      // Focus the select for correction
      this.selectTarget.focus()

      // Remove error styling after 3 seconds
      setTimeout(() => {
        this.selectTarget.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
        this.selectTarget.classList.add("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
        this.selectTarget.removeAttribute("aria-invalid")
      }, 3000)
    }
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
   * Validate form before submission
   * Ensures a label is selected
   *
   * @param {Event} event - Submit event
   */
  validateForm(event) {
    if (this.hasSelectTarget && !this.selectTarget.value) {
      event.preventDefault()

      // Show error feedback
      this.showError()

      // Announce error
      this.announceToScreenReader("Please select a label before adding")

      return false
    }

    return true
  }
}
