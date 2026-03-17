import { Controller } from "@hotwired/stimulus"

// Manages the inventory grid for batch editing.
// Handles dirty tracking, total calculations, fill operations,
// keyboard navigation, and beforeunload guard.
export default class extends Controller {
  static targets = ["cell", "rowTotal", "columnTotal", "grandTotal", "saveButton", "dirtyCount", "fillInput", "form"]
  static values = { dirty: { type: Boolean, default: false } }

  connect() {
    this.originalValues = new Map()
    this.cellTargets.forEach(cell => {
      this.originalValues.set(cell.dataset.cellKey, cell.value)
    })

    this.beforeUnloadHandler = (e) => {
      if (this.dirtyValue) { e.preventDefault() }
    }
    window.addEventListener("beforeunload", this.beforeUnloadHandler)
    this.updateTotals()
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
  }

  // Called on input event of any cell (user typing)
  cellChanged(event) {
    const cell = event.target
    const key = cell.dataset.cellKey
    const original = this.originalValues.get(key)
    const isDirty = cell.value !== original

    // Use inline styles — Tailwind JIT won't compile classes only used in JS
    cell.style.backgroundColor = isDirty ? "#fefce8" : ""
    cell.style.borderColor = isDirty ? "#facc15" : ""

    this.updateTotals()
    this.dirtyValue = this.cellTargets.some(c =>
      c.value !== this.originalValues.get(c.dataset.cellKey)
    )
  }

  dirtyValueChanged() {
    // Guard: Stimulus calls this for default values BEFORE connect() runs
    if (!this.originalValues) return

    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = !this.dirtyValue
      this.saveButtonTarget.classList.toggle("opacity-50", !this.dirtyValue)
    }
    if (this.hasDirtyCountTarget) {
      const count = this.cellTargets.filter(c =>
        c.value !== this.originalValues.get(c.dataset.cellKey)
      ).length
      this.dirtyCountTarget.textContent = count > 0 ? `${count} changed` : ""
    }
  }

  updateTotals() {
    const rowSums = {}
    const colSums = {}

    this.cellTargets.forEach(cell => {
      if (cell.disabled) return

      const rowId = cell.dataset.rowId
      const colId = cell.dataset.colId
      const val = parseInt(cell.value) || 0

      rowSums[rowId] = (rowSums[rowId] || 0) + val
      colSums[colId] = (colSums[colId] || 0) + val
    })

    this.rowTotalTargets.forEach(el => {
      const rowId = el.dataset.rowId
      if (rowId in rowSums) el.textContent = rowSums[rowId].toLocaleString()
    })

    this.columnTotalTargets.forEach(el => {
      const colId = el.dataset.colId
      if (colId in colSums) el.textContent = colSums[colId].toLocaleString()
    })

    if (this.hasGrandTotalTarget) {
      const grand = Object.values(colSums).reduce((a, b) => a + b, 0)
      this.grandTotalTarget.textContent = grand.toLocaleString()
    }
  }

  // Fill all empty/zero cells with the value from fillInput
  fillAll() {
    const value = this.hasFillInputTarget ? this.fillInputTarget.value : ""
    if (!value) return

    // Fill all enabled cells with the value
    this.cellTargets.forEach(cell => {
      if (cell.disabled) return
      cell.value = value
    })

    // Update totals and dirty state directly (dispatchEvent was unreliable for this)
    this.updateTotals()
    this.dirtyValue = true
  }

  // Fill empty cells in a specific column
  fillColumn(event) {
    const colId = event.params.colId
    const value = this.hasFillInputTarget ? this.fillInputTarget.value : ""
    if (!value) return

    this.cellTargets
      .filter(c => !c.disabled && c.dataset.colId === String(colId))
      .forEach(cell => {
        cell.value = value
      })

    this.updateTotals()
    this.dirtyValue = true
  }

  // Submit the form when Save All is clicked
  save() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  // Keyboard navigation: Enter moves down
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      const cells = this.cellTargets
      const currentIndex = cells.indexOf(event.target)
      const colId = event.target.dataset.colId

      for (let i = currentIndex + 1; i < cells.length; i++) {
        if (cells[i].dataset.colId === colId && !cells[i].disabled) {
          cells[i].focus()
          cells[i].select()
          return
        }
      }
    }
  }

  // Open the adjust inventory modal from a pencil icon click
  openAdjustModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const data = button.dataset

    // Update modal header and product info
    document.getElementById('modal-product-name').textContent = `Adjust Inventory - ${data.productSku}`
    document.getElementById('modal-product-sku').textContent = data.productSku
    document.getElementById('modal-product-description').textContent = data.productName

    // Update storage info
    const storageNameEl = document.getElementById('modal-storage-name')
    const storageCodeEl = document.getElementById('modal-storage-code')
    if (storageNameEl) storageNameEl.textContent = data.storageName
    if (storageCodeEl) storageCodeEl.textContent = data.storageCode

    // Update form action URL
    const form = document.getElementById('adjust-inventory-form')
    form.action = data.updateUrl
    form.reset()

    // Populate fields
    const valueInput = document.getElementById('inventory-value')
    const etaQtyInput = document.getElementById('eta-quantity')
    const etaDateInput = document.getElementById('eta-date')

    if (valueInput) valueInput.value = parseInt(data.currentValue) || 0
    if (etaQtyInput) etaQtyInput.value = parseInt(data.etaQuantity) || 0
    if (etaDateInput && data.etaDate) etaDateInput.value = data.etaDate

    // Update total available
    const inventoryFormEl = form.closest('[data-controller="inventory-form"]')
    if (inventoryFormEl) {
      const ctrl = this.application.getControllerForElementAndIdentifier(inventoryFormEl, "inventory-form")
      if (ctrl) ctrl.updateTotalAvailable()
    }

    // Open the modal
    setTimeout(() => {
      const modalEl = document.querySelector('[data-controller~="modal"][data-modal-closable-value="true"]')
      if (modalEl) {
        const modalCtrl = this.application.getControllerForElementAndIdentifier(modalEl, "modal")
        if (modalCtrl) modalCtrl.open()
      }
    }, 50)
  }
}
