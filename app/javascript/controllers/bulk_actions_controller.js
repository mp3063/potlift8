import { Controller } from "@hotwired/stimulus"

/**
 * Bulk Actions Controller
 *
 * Manages bulk operations on products:
 * - Checkbox selection (individual and select all)
 * - Bulk delete with confirmation
 * - Bulk CSV export
 * - Toolbar visibility based on selection
 *
 * Targets:
 * - checkbox: Individual product checkboxes
 * - toolbar: Bulk actions toolbar (shown when items selected)
 * - count: Display count of selected items
 *
 * Actions:
 * - toggleAll: Select/deselect all products
 * - toggleCheckbox: Toggle individual product selection
 * - bulkDelete: Delete selected products
 * - bulkExport: Export selected products to CSV
 */
export default class extends Controller {
  static targets = ["checkbox", "toolbar", "count"]

  /**
   * Initialize controller
   * Sets up selected IDs tracking
   */
  connect() {
    this.selectedIds = new Set()
    this.updateToolbar()
  }

  /**
   * Toggle all checkboxes
   *
   * @param {Event} event - Change event from select-all checkbox
   */
  toggleAll(event) {
    const checked = event.target.checked

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      if (checked) {
        this.selectedIds.add(checkbox.value)
      } else {
        this.selectedIds.delete(checkbox.value)
      }
    })

    this.updateToolbar()
  }

  /**
   * Toggle individual checkbox
   *
   * @param {Event} event - Change event from individual checkbox
   */
  toggleCheckbox(event) {
    const checkbox = event.target

    if (checkbox.checked) {
      this.selectedIds.add(checkbox.value)
    } else {
      this.selectedIds.delete(checkbox.value)
    }

    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  /**
   * Update toolbar visibility based on selection
   */
  updateToolbar() {
    if (this.selectedIds.size > 0) {
      this.showToolbar()
      this.updateCount()
    } else {
      this.hideToolbar()
    }
  }

  /**
   * Show bulk actions toolbar
   */
  showToolbar() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.remove("hidden")
    }
  }

  /**
   * Hide bulk actions toolbar
   */
  hideToolbar() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.add("hidden")
    }
  }

  /**
   * Update selected count display
   */
  updateCount() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.selectedIds.size
    }
  }

  /**
   * Update select-all checkbox state
   * Sets indeterminate if some but not all items selected
   */
  updateSelectAllCheckbox() {
    const selectAllCheckbox = document.querySelector('[data-action="change->bulk-actions#toggleAll"]')
    if (!selectAllCheckbox) return

    const totalCheckboxes = this.checkboxTargets.length
    const selectedCount = this.selectedIds.size

    if (selectedCount === 0) {
      selectAllCheckbox.checked = false
      selectAllCheckbox.indeterminate = false
    } else if (selectedCount === totalCheckboxes) {
      selectAllCheckbox.checked = true
      selectAllCheckbox.indeterminate = false
    } else {
      selectAllCheckbox.checked = false
      selectAllCheckbox.indeterminate = true
    }
  }

  /**
   * Bulk delete selected products
   * Shows confirmation dialog before proceeding
   */
  bulkDelete() {
    if (this.selectedIds.size === 0) {
      return
    }

    const count = this.selectedIds.size
    const message = `Are you sure you want to delete ${count} selected product${count > 1 ? 's' : ''}?`

    if (!confirm(message)) {
      return
    }

    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/products/bulk_destroy"

    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

    // Add product IDs
    this.selectedIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "product_ids[]"
      input.value = id
      form.appendChild(input)
    })

    document.body.appendChild(form)
    form.submit()
  }

  /**
   * Bulk export selected products to CSV
   * Opens download in current window
   */
  bulkExport() {
    if (this.selectedIds.size === 0) {
      return
    }

    const ids = Array.from(this.selectedIds).join(",")
    window.location.href = `/products.csv?ids=${ids}`
  }

  /**
   * Clear all selections
   * Useful for resetting state after operations
   */
  clearSelection() {
    this.selectedIds.clear()
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }
}
