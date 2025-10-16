import { Controller } from "@hotwired/stimulus"

/**
 * Filter panel controller for advanced filtering
 *
 * Handles filter panel interactions:
 * - Toggle mobile filter panel
 * - Form submission
 * - Visual feedback
 *
 * @example
 *   <div data-controller="filter-panel">
 *     <button data-action="click->filter-panel#toggleMobile">Toggle Filters</button>
 *     <div data-filter-panel-target="panel" class="hidden lg:block">
 *       <!-- Filter form -->
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["panel"]

  /**
   * Toggle mobile filter panel visibility
   * Shows/hides the filter panel on mobile devices
   */
  toggleMobile(event) {
    if (event) event.preventDefault()

    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden")

      // Update button ARIA state
      const button = event.currentTarget
      const isExpanded = !this.panelTarget.classList.contains("hidden")
      button.setAttribute("aria-expanded", isExpanded)
    }
  }

  /**
   * Handle form submission
   * Provides visual feedback during filter application
   */
  submit(event) {
    // Optional: Add loading indicator
    const submitButton = event.target.querySelector('button[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = "Applying..."

      // Re-enable after a short delay (Turbo will handle the actual submission)
      setTimeout(() => {
        submitButton.disabled = false
        submitButton.textContent = "Apply Filters"
      }, 1000)
    }
  }
}
