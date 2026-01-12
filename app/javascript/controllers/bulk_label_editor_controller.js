import { Controller } from "@hotwired/stimulus"

/**
 * Bulk Label Editor Controller
 *
 * Manages the bulk label editing modal for products:
 * - Tracks selected labels
 * - Updates label count display
 * - Populates form with product IDs from bulk selection
 * - Handles form submission with action type (add/remove)
 * - Filters labels based on action type (shows only assigned labels for remove)
 *
 * Targets:
 * - form: The label form element
 * - labelCheckbox: Individual label checkboxes
 * - labelRow: Label row elements (for filtering)
 * - selectedLabelCount: Display count of selected labels
 * - productIds: Container for hidden product ID inputs
 * - actionType: Radio buttons for add/remove action
 * - submitButton: Form submit button
 *
 * Actions:
 * - clearLabels: Deselect all labels
 * - updateLabelCount: Update label count display
 * - handleActionTypeChange: Filter labels when switching to remove mode
 *
 * Integration:
 * - Works with bulk_actions_controller to get selected product IDs
 * - Submits to bulk_update_labels_products_path
 */
export default class extends Controller {
  static targets = [
    "form",
    "labelCheckbox",
    "labelRow",
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

    // Store current product IDs
    this.currentProductIds = []

    // Cache for labels assigned to products
    this.labelData = null // { assigned_to_any: Set, assigned_to_all: Set }
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

    // Store product IDs for later use
    this.currentProductIds = productIds

    // Reset cache when products change
    this.labelData = null

    // Clear existing inputs safely
    while (this.productIdsTarget.firstChild) {
      this.productIdsTarget.removeChild(this.productIdsTarget.firstChild)
    }

    // Add hidden input for each product ID
    productIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "product_ids[]"
      input.value = id
      this.productIdsTarget.appendChild(input)
    })

    // Reset to "Add" mode and filter labels
    const addRadio = this.actionTypeTargets.find(r => r.value === "add")
    if (addRadio) {
      addRadio.checked = true
    }
    this.clearLabels()
    // Filter for add mode (async)
    this.filterLabelsForAdd()
  }

  /**
   * Handle action type change (add/remove radio buttons)
   * Filters labels based on selected action type
   *
   * @param {Event} event - Change event from radio button
   */
  async handleActionTypeChange(event) {
    const actionType = event.target.value

    // Clear current selections when switching modes
    this.clearLabels()

    if (actionType === "remove") {
      await this.filterLabelsForRemove()
    } else {
      await this.filterLabelsForAdd()
    }
  }

  /**
   * Fetch label data from API (cached)
   */
  async fetchLabelData() {
    if (this.labelData !== null) {
      return this.labelData
    }

    if (this.currentProductIds.length === 0) {
      this.labelData = {
        assigned_to_any: new Set(),
        assigned_to_all: new Set()
      }
      return this.labelData
    }

    try {
      const params = new URLSearchParams()
      this.currentProductIds.forEach(id => params.append("product_ids[]", id))

      const response = await fetch(`/products/bulk/labels_for_products?${params}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error("Failed to fetch labels")
      }

      const data = await response.json()
      this.labelData = {
        assigned_to_any: new Set(data.assigned_to_any.map(id => id.toString())),
        assigned_to_all: new Set(data.assigned_to_all.map(id => id.toString()))
      }
      return this.labelData
    } catch (error) {
      console.error("Error fetching labels for products:", error)
      // On error, return empty sets
      this.labelData = {
        assigned_to_any: new Set(),
        assigned_to_all: new Set()
      }
      return this.labelData
    }
  }

  /**
   * Filter labels for "Add" mode
   * Hides labels that ALL selected products already have
   */
  async filterLabelsForAdd() {
    const data = await this.fetchLabelData()

    // Filter labels - hide those assigned to ALL selected products
    this.labelCheckboxTargets.forEach(checkbox => {
      const labelId = checkbox.value
      const labelRow = checkbox.closest("label")

      if (data.assigned_to_all.has(labelId)) {
        // Already on all products, hide it
        labelRow.classList.add("hidden")
        checkbox.checked = false
      } else {
        labelRow.classList.remove("hidden")
      }
    })

    this.updateLabelCount()
  }

  /**
   * Filter labels for "Remove" mode
   * Shows only labels assigned to ANY of the selected products
   */
  async filterLabelsForRemove() {
    const data = await this.fetchLabelData()

    // Filter labels - show only those assigned to selected products
    this.labelCheckboxTargets.forEach(checkbox => {
      const labelId = checkbox.value
      const labelRow = checkbox.closest("label")

      if (data.assigned_to_any.has(labelId)) {
        labelRow.classList.remove("hidden")
      } else {
        labelRow.classList.add("hidden")
        checkbox.checked = false
      }
    })

    this.updateLabelCount()
  }

  /**
   * Show all labels (fallback)
   */
  showAllLabels() {
    this.labelCheckboxTargets.forEach(checkbox => {
      const labelRow = checkbox.closest("label")
      labelRow.classList.remove("hidden")
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
