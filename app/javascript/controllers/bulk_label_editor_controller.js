import { Controller } from "@hotwired/stimulus"

/**
 * Bulk Label Editor Controller
 *
 * Manages the bulk label editing modal for products:
 * - Tracks selected labels
 * - Updates label count display
 * - Populates form with product IDs from bulk selection
 * - Handles form submission with action type (add/remove)
 *
 * Targets:
 * - form: The label form element
 * - labelCheckbox: Individual label checkboxes
 * - selectedLabelCount: Display count of selected labels
 * - productIds: Container for hidden product ID inputs
 * - actionType: Radio buttons for add/remove action
 * - submitButton: Form submit button
 *
 * Actions:
 * - clearLabels: Deselect all labels
 * - updateLabelCount: Update label count display
 *
 * Integration:
 * - Works with bulk_actions_controller to get selected product IDs
 * - Submits to bulk_update_labels_products_path
 */
export default class extends Controller {
  static targets = [
    "form",
    "labelCheckbox",
    "selectedLabelCount",
    "productIds",
    "actionType",
    "submitButton"
  ]

  /**
   * Initialize controller
   * Set up event listeners
   */
  connect() {
    // Listen for checkbox changes to update count
    this.labelCheckboxTargets.forEach(checkbox => {
      checkbox.addEventListener("change", () => this.updateLabelCount())
    })

    // Initialize count
    this.updateLabelCount()
  }

  /**
   * Update the selected label count display
   */
  updateLabelCount() {
    const count = this.getSelectedLabels().length
    if (this.hasSelectedLabelCountTarget) {
      this.selectedLabelCountTarget.textContent = count
    }

    // Enable/disable submit button based on selection
    if (this.hasSubmitButtonTarget) {
      const button = this.submitButtonTarget.querySelector("button")
      if (button) {
        button.disabled = count === 0
        if (count === 0) {
          button.classList.add("opacity-50", "cursor-not-allowed")
        } else {
          button.classList.remove("opacity-50", "cursor-not-allowed")
        }
      }
    }
  }

  /**
   * Get array of selected label IDs
   *
   * @returns {Array<string>} Array of label IDs
   */
  getSelectedLabels() {
    return this.labelCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  /**
   * Clear all label selections
   */
  clearLabels() {
    this.labelCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateLabelCount()
  }

  /**
   * Populate form with product IDs from bulk selection
   * Called by bulk_actions_controller before opening modal
   *
   * @param {Array<string>} productIds - Array of product IDs
   */
  setProductIds(productIds) {
    if (!this.hasProductIdsTarget) return

    // Clear existing inputs
    this.productIdsTarget.innerHTML = ""

    // Add hidden input for each product ID
    productIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "product_ids[]"
      input.value = id
      this.productIdsTarget.appendChild(input)
    })
  }

  /**
   * Get selected action type (add or remove)
   *
   * @returns {string} "add" or "remove"
   */
  getActionType() {
    const checkedRadio = this.actionTypeTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value : "add"
  }

  /**
   * Handle form submission
   * Adds action type to form data
   *
   * @param {Event} event - Submit event
   */
  submit(event) {
    const selectedLabels = this.getSelectedLabels()
    const actionType = this.getActionType()

    if (selectedLabels.length === 0) {
      event.preventDefault()
      alert("Please select at least one label")
      return
    }

    // Add action type to form
    const actionInput = document.createElement("input")
    actionInput.type = "hidden"
    actionInput.name = "action_type"
    actionInput.value = actionType
    this.formTarget.appendChild(actionInput)

    // Form will submit normally
  }
}
