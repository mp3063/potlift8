import { Controller } from "@hotwired/stimulus"

/**
 * Product Selector Controller
 *
 * Manages product selection interface for adding products to storage locations.
 * Provides bulk selection controls, search handling, and selected count tracking.
 *
 * Targets:
 * - checkbox: Individual product checkboxes
 * - selectedCount: Element displaying count of selected products
 * - submitButton: Form submit button (optional, for disabling when no selection)
 * - form: The product selection form
 * - productList: Container for product rows
 * - productRow: Individual product table rows
 *
 * Actions:
 * - selectAll: Select all visible product checkboxes
 * - deselectAll: Deselect all product checkboxes
 * - updateCount: Update the selected product count display
 * - handleSearch: Handle search form submission (auto-submit on filter change)
 *
 * Usage:
 *   <div data-controller="product-selector">
 *     <button data-action="click->product-selector#selectAll">Select All</button>
 *     <span data-product-selector-target="selectedCount">0</span>
 *     <input type="checkbox" data-product-selector-target="checkbox">
 *   </div>
 */
export default class extends Controller {
  static targets = ["checkbox", "selectedCount", "submitButton", "form", "productList", "productRow", "selectAll", "count", "productCheckbox"]

  /**
   * Initialize controller
   * Updates count on connect to handle pre-selected checkboxes
   */
  connect() {
    console.log('ProductSelectorController connected')
    console.log('Checkboxes found:', this.checkboxTargets.length)
    console.log('Has selectedCount target:', this.hasSelectedCountTarget)
    console.log('Has submitButton target:', this.hasSubmitButtonTarget)
    this.updateCount()
    this.updateSubmitButton()
  }

  /**
   * Select all product checkboxes
   *
   * @param {Event} event - Click event
   */
  selectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })

    this.updateCount()
  }

  /**
   * Deselect all product checkboxes
   *
   * @param {Event} event - Click event
   */
  deselectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })

    this.updateCount()
  }

  /**
   * Update the selected product count display
   * Also enables/disables submit button based on selection
   */
  updateCount() {
    const selectedCount = this.selectedCheckboxes.length
    console.log('updateCount called, selectedCount:', selectedCount)

    // Update count display
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
      console.log('Updated selectedCountTarget to:', selectedCount)
    } else {
      console.warn('selectedCountTarget not found!')
    }

    // Update alternate count target
    if (this.hasCountTarget) {
      this.countTarget.textContent = selectedCount
    }

    this.updateSubmitButton()
  }

  /**
   * Enable/disable submit button based on selection
   */
  updateSubmitButton() {
    if (!this.hasSubmitButtonTarget) {
      console.warn('updateSubmitButton: submitButtonTarget not found')
      return
    }

    const selectedCount = this.selectedCheckboxes.length
    const submitButton = this.submitButtonTarget
    const buttonElement = submitButton.querySelector('button') || submitButton

    console.log('updateSubmitButton: selectedCount:', selectedCount, 'buttonElement:', buttonElement)

    if (selectedCount === 0) {
      buttonElement.disabled = true
      buttonElement.classList.add('opacity-50', 'cursor-not-allowed')
      console.log('Submit button disabled')
    } else {
      buttonElement.disabled = false
      buttonElement.classList.remove('opacity-50', 'cursor-not-allowed')
      console.log('Submit button enabled')
    }
  }

  /**
   * Toggle all product checkboxes on/off
   *
   * @param {Event} event - Change event from select all checkbox
   */
  toggleAll(event) {
    const checked = event.target.checked
    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets

    targets.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateCount()
  }

  /**
   * Toggle individual product checkbox and update select all state
   *
   * @param {Event} event - Change event
   */
  toggleProduct(event) {
    this.updateCount()
    this.updateSelectAllState()
  }

  /**
   * Update select all checkbox state (checked/unchecked/indeterminate)
   */
  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return

    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets
    const total = targets.length
    const checked = this.selectedCheckboxes.length

    if (checked === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checked === total) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
  }

  /**
   * Handle search form changes
   * Auto-submits the search form when filters change
   *
   * @param {Event} event - Change event from select/input
   */
  handleSearch(event) {
    // For select elements, auto-submit the form
    if (event.target.tagName === 'SELECT') {
      event.target.form.requestSubmit()
    }
  }

  /**
   * Get array of selected checkboxes
   *
   * @returns {Array} Array of checked checkbox elements
   */
  get selectedCheckboxes() {
    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets
    return targets.filter(checkbox => checkbox.checked)
  }

  /**
   * Get array of selected product IDs
   *
   * @returns {Array} Array of product ID values
   */
  get selectedProductIds() {
    return this.selectedCheckboxes.map(checkbox => checkbox.value)
  }
}
