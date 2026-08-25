import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAllCheckbox", "toolbar", "selectedCount"]
  static values = {
    deleteUrl: String
  }

  connect() {
    this.updateToolbar()
  }

  toggle() {
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  toggleAll() {
    const checked = this.selectAllCheckboxTarget.checked

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateToolbar()
  }

  selectAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  deselectAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

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

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      alert("Failed to delete images. Please refresh and try again.")
      return
    }

    this.showLoadingState()

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
      window.location.reload()
    })
    .catch(error => {
      console.error("Error deleting images:", error)
      this.hideLoadingState()
      alert("Failed to delete images. Please try again.")
    })
  }

  getSelectedIds() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  getSelectedCount() {
    return this.getSelectedIds().length
  }

  updateToolbar() {
    const selectedCount = this.getSelectedCount()

    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }

    if (this.hasToolbarTarget) {
      if (selectedCount > 0) {
        this.toolbarTarget.classList.remove("hidden")
      } else {
        this.toolbarTarget.classList.add("hidden")
      }
    }
  }

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

  showLoadingState() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.add("opacity-50", "pointer-events-none")
    }

    this.checkboxTargets.forEach(checkbox => {
      checkbox.disabled = true
    })

    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.disabled = true
    }
  }

  hideLoadingState() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.remove("opacity-50", "pointer-events-none")
    }

    this.checkboxTargets.forEach(checkbox => {
      checkbox.disabled = false
    })

    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.disabled = false
    }
  }
}
