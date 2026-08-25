import { Controller } from "@hotwired/stimulus"

/**
 * Since table rows (<tr>) cannot be nested, this controller finds sibling rows
 * that have matching parent-id data attributes to show/hide child rows.
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

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.expandedValue = !this.expandedValue
  }

  expand() {
    this.expandedValue = true
  }

  collapse() {
    this.expandedValue = false
  }

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

    const table = this.element.closest('table')
    if (!table) return []

    return Array.from(table.querySelectorAll(`tr[data-parent-id="${productId}"]`))
  }

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

  updateIcon() {
    if (this.hasIconTarget) {
      if (this.expandedValue) {
        this.iconTarget.classList.add("rotate-90")
      } else {
        this.iconTarget.classList.remove("rotate-90")
      }
    }
  }

  updateTriggerAria() {
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", this.expandedValue.toString())
    }
  }
}
