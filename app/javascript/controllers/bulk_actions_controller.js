import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "toolbar", "count", "labelEditorTrigger"]

  connect() {
    this.selectedIds = new Set()
    this.updateToolbar()
  }

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

  toggleCheckbox(event) {
    const checkbox = event.target
    const isParent = checkbox.dataset.parentCheckbox === "true"
    const parentId = checkbox.value

    if (checkbox.checked) {
      this.selectedIds.add(checkbox.value)

      if (isParent) {
        this.getChildCheckboxes(parentId).forEach(childCheckbox => {
          childCheckbox.checked = true
          this.selectedIds.add(childCheckbox.value)
        })
      }
    } else {
      this.selectedIds.delete(checkbox.value)

      if (isParent) {
        this.getChildCheckboxes(parentId).forEach(childCheckbox => {
          childCheckbox.checked = false
          this.selectedIds.delete(childCheckbox.value)
        })
      }
    }

    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }

  getChildCheckboxes(parentId) {
    return this.checkboxTargets.filter(
      checkbox => checkbox.dataset.childOf === parentId
    )
  }

  updateToolbar() {
    if (this.selectedIds.size > 0) {
      this.showToolbar()
      this.updateCount()
    } else {
      this.hideToolbar()
    }
  }

  showToolbar() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.remove("hidden")
    }
  }

  hideToolbar() {
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.add("hidden")
    }
  }

  updateCount() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.selectedIds.size
    }
  }

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

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

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

  bulkExport() {
    if (this.selectedIds.size === 0) {
      return
    }

    const ids = Array.from(this.selectedIds).join(",")
    window.location.href = `/products.csv?ids=${ids}`
  }

  openLabelEditor() {
    if (this.selectedIds.size === 0) {
      alert("Please select at least one product")
      return
    }

    const labelEditorController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="bulk-label-editor"]'),
      "bulk-label-editor"
    )

    if (labelEditorController) {
      labelEditorController.setProductIds(Array.from(this.selectedIds))

      if (this.hasLabelEditorTriggerTarget) {
        this.labelEditorTriggerTarget.click()
      }
    } else {
      console.error("Bulk label editor controller not found")
    }
  }

  clearSelection() {
    this.selectedIds.clear()
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateToolbar()
    this.updateSelectAllCheckbox()
  }
}
