import { Controller } from "@hotwired/stimulus"

/**
 * Expandable row controller for hierarchical product display
 *
 * Handles expand/collapse functionality for configurable products and bundles
 * in the products table, showing/hiding subproducts (variants or bundle components).
 *
 * Since table rows (<tr>) cannot be nested, this controller finds sibling rows
 * that have matching parent-id data attributes to show/hide child rows.
 *
 * @example
 *   <tr data-controller="expandable-row" data-product-id="123">
 *     <td>
 *       <button data-action="click->expandable-row#toggle" data-expandable-row-target="trigger">
 *         <svg data-expandable-row-target="icon">...</svg>
 *       </button>
 *     </td>
 *   </tr>
 *   <tr class="hidden" data-parent-id="123">
 *     <!-- Child product row -->
 *   </tr>
 */
export default class extends Controller {
  static targets = ["trigger", "icon"]
  static classes = ["expanded"]
  static values = {
    expanded: { type: Boolean, default: false }
  }

  connect() {
    this.updateVisibility()
  }

  /**
   * Toggle expanded state
   */
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.expandedValue = !this.expandedValue
  }

  /**
   * Expand the row
   */
  expand() {
    this.expandedValue = true
  }

  /**
   * Collapse the row
   */
  collapse() {
    this.expandedValue = false
  }

  /**
   * Handle expanded value change
   */
  expandedValueChanged() {
    this.updateVisibility()
    this.updateIcon()
    this.updateTriggerAria()
  }

  /**
   * Find child rows by looking for sibling rows with matching parent-id
   * This is necessary because table rows cannot be nested in HTML
   */
  getChildRows() {
    const productId = this.element.dataset.productId
    if (!productId) return []

    // Find all sibling rows that have this product as their parent
    const table = this.element.closest('table')
    if (!table) return []

    return Array.from(table.querySelectorAll(`tr[data-parent-id="${productId}"]`))
  }

  /**
   * Update content visibility based on expanded state
   */
  updateVisibility() {
    const childRows = this.getChildRows()

    childRows.forEach(row => {
      if (this.expandedValue) {
        row.classList.remove("hidden")
      } else {
        row.classList.add("hidden")
      }
    })
  }

  /**
   * Update icon rotation based on expanded state
   */
  updateIcon() {
    if (this.hasIconTarget) {
      if (this.expandedValue) {
        this.iconTarget.classList.add("rotate-90")
      } else {
        this.iconTarget.classList.remove("rotate-90")
      }
    }
  }

  /**
   * Update trigger ARIA attributes
   */
  updateTriggerAria() {
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", this.expandedValue.toString())
    }
  }
}
