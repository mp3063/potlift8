import { Controller } from "@hotwired/stimulus"

// Manages the inventory grid for batch editing.
// Handles dirty tracking, total calculations, fill operations,
// keyboard navigation, and beforeunload guard.
export default class extends Controller {
  static targets = ["cell", "rowTotal", "columnTotal", "grandTotal", "saveButton", "dirtyCount", "fillInput"]
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

  // Called on input event of any cell
  cellChanged(event) {
    const cell = event.target
    const key = cell.dataset.cellKey
    const original = this.originalValues.get(key)
    const isDirty = cell.value !== original

    cell.classList.toggle("bg-yellow-50", isDirty)
    cell.classList.toggle("border-yellow-400", isDirty)
    cell.classList.toggle("border-gray-300", !isDirty)

    this.updateTotals()
    this.dirtyValue = this.cellTargets.some(c =>
      c.value !== this.originalValues.get(c.dataset.cellKey)
    )
  }

  dirtyValueChanged() {
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
    // Row totals
    const rowSums = {}
    const colSums = {}

    this.cellTargets.forEach(cell => {
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

    this.cellTargets.forEach(cell => {
      if (!cell.value || cell.value === "0") {
        cell.value = value
        cell.dispatchEvent(new Event("input", { bubbles: true }))
      }
    })
  }

  // Fill empty cells in a specific column
  fillColumn(event) {
    const colId = event.params.colId
    const value = this.hasFillInputTarget ? this.fillInputTarget.value : ""
    if (!value) return

    this.cellTargets
      .filter(c => c.dataset.colId === String(colId))
      .forEach(cell => {
        if (!cell.value || cell.value === "0") {
          cell.value = value
          cell.dispatchEvent(new Event("input", { bubbles: true }))
        }
      })
  }

  // Keyboard navigation: Enter moves down
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      const cells = this.cellTargets
      const currentIndex = cells.indexOf(event.target)
      const colId = event.target.dataset.colId

      // Find next cell in same column
      for (let i = currentIndex + 1; i < cells.length; i++) {
        if (cells[i].dataset.colId === colId) {
          cells[i].focus()
          cells[i].select()
          return
        }
      }
    }
  }
}
