import { Controller } from "@hotwired/stimulus"

/**
 * Bulk Images Controller
 *
 * Handles bulk selection and operations on product images.
 * Allows users to select multiple images and perform batch operations
 * like deletion or metadata updates.
 *
 * Data Attributes:
 * - data-bulk-images-delete-url-value: URL for bulk delete endpoint
 *
 * Targets:
 * - checkbox: Individual image checkboxes
 * - selectAllCheckbox: Master checkbox to select/deselect all
 * - toolbar: Bulk operations toolbar
 * - selectedCount: Element displaying count of selected images
 *
 * @example
 *   <div data-controller="bulk-images"
 *        data-bulk-images-delete-url-value="/products/123/images/bulk_destroy">
 *     <input type="checkbox" data-bulk-images-target="selectAllCheckbox"
 *            data-action="change->bulk-images#toggleAll">
 *     <input type="checkbox" data-bulk-images-target="checkbox"
 *            data-action="change->bulk-images#toggle" value="1">
 *   </div>
 */
export default class extends Controller {
  static targets = ["checkbox", "selectAllCheckbox", "toolbar", "selectedCount"]
  static values = {
    deleteUrl: String
  }

  connect() {
    this.updateToolbar()
  }

  /**
   * Toggle individual checkbox
   * Updates toolbar and select-all checkbox state
   */
  toggle() {
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  /**
   * Toggle all checkboxes
   * Selects or deselects all images based on master checkbox
   */
  toggleAll() {
    const checked = this.selectAllCheckboxTarget.checked

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateToolbar()
  }

  /**
   * Select all images
   */
  selectAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  /**
   * Deselect all images
   */
  deselectAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  /**
   * Delete selected images
   * Confirms action and sends bulk delete request
   */
  deleteSelected() {
    const selectedIds = this.getSelectedIds()

    if (selectedIds.length === 0) {
      alert("Please select at least one image to delete.")
      return
    }

    const confirmMessage = `Are you sure you want to delete ${selectedIds.length} ${selectedIds.length === 1 ? 'image' : 'images'}?`

    if (!confirm(confirmMessage)) {
      return
    }

    // Get CSRF token
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      alert("Failed to delete images. Please refresh and try again.")
      return
    }

    // Show loading state
    this.showLoadingState()

    // Send bulk delete request
    fetch(this.deleteUrlValue, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ image_ids: selectedIds })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      // Reload page to show updated images
      window.location.reload()
    })
    .catch(error => {
      console.error("Error deleting images:", error)
      this.hideLoadingState()
      alert("Failed to delete images. Please try again.")
    })
  }

  /**
   * Get IDs of selected images
   * @returns {Array<String>} Array of image IDs
   */
  getSelectedIds() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  /**
   * Get count of selected images
   * @returns {Number} Count of selected images
   */
  getSelectedCount() {
    return this.getSelectedIds().length
  }

  /**
   * Update toolbar visibility and selected count
   */
  updateToolbar() {
    const selectedCount = this.getSelectedCount()

    // Update selected count display
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }

    // Show/hide toolbar based on selection
    if (this.hasToolbarTarget) {
      if (selectedCount > 0) {
        this.toolbarTarget.classList.remove("hidden")
      } else {
        this.toolbarTarget.classList.add("hidden")
      }
    }
  }

  /**
   * Update select-all checkbox state
   * Sets to checked if all images are selected, unchecked if none,
   * or indeterminate if some are selected
   */
  updateSelectAllCheckbox() {
    if (!this.hasSelectAllCheckboxTarget) return

    const totalCheckboxes = this.checkboxTargets.length
    const selectedCount = this.getSelectedCount()

    if (selectedCount === 0) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    } else if (selectedCount === totalCheckboxes) {
      this.selectAllCheckboxTarget.checked = true
      this.selectAllCheckboxTarget.indeterminate = false
    } else {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = true
    }
  }

  /**
   * Show loading state
   */
  showLoadingState() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.add("opacity-50", "pointer-events-none")
    }

    // Disable all checkboxes
    this.checkboxTargets.forEach(checkbox => {
      checkbox.disabled = true
    })

    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.disabled = true
    }
  }

  /**
   * Hide loading state
   */
  hideLoadingState() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.remove("opacity-50", "pointer-events-none")
    }

    // Re-enable all checkboxes
    this.checkboxTargets.forEach(checkbox => {
      checkbox.disabled = false
    })

    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.disabled = false
    }
  }
}
