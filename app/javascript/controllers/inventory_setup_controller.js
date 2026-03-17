import { Controller } from "@hotwired/stimulus"

// Manages the inventory setup wizard for products with no inventory.
// Step 1: Select storages → Step 2: Fill grid
export default class extends Controller {
  static targets = ["storageCheckbox", "step1", "step2", "continueButton", "gridContainer"]

  connect() {
    this.updateContinueButton()
  }

  // Toggle checkbox and update button state
  toggleStorage() {
    this.updateContinueButton()
  }

  updateContinueButton() {
    const anyChecked = this.storageCheckboxTargets.some(cb => cb.checked)
    if (this.hasContinueButtonTarget) {
      this.continueButtonTarget.disabled = !anyChecked
      this.continueButtonTarget.classList.toggle("opacity-50", !anyChecked)
    }
  }

  selectAll() {
    this.storageCheckboxTargets.forEach(cb => { cb.checked = true })
    this.updateContinueButton()
  }

  deselectAll() {
    this.storageCheckboxTargets.forEach(cb => { cb.checked = false })
    this.updateContinueButton()
  }

  // Transition from Step 1 to Step 2
  continue() {
    const selectedStorages = this.storageCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.storageId)

    if (selectedStorages.length === 0) return

    // Hide unselected storage columns in the grid
    if (this.hasGridContainerTarget) {
      const allCols = this.gridContainerTarget.querySelectorAll("[data-storage-col]")
      allCols.forEach(col => {
        const storageId = col.dataset.storageCol
        col.classList.toggle("hidden", !selectedStorages.includes(storageId))
      })

      // Also hide/disable inputs in unselected storage columns
      const allInputs = this.gridContainerTarget.querySelectorAll("input[data-col-id]")
      allInputs.forEach(input => {
        const colId = input.dataset.colId
        if (!selectedStorages.includes(colId)) {
          input.disabled = true
          input.closest("td")?.classList.add("hidden")
        }
      })
    }

    // Transition steps
    if (this.hasStep1Target) this.step1Target.classList.add("hidden")
    if (this.hasStep2Target) this.step2Target.classList.remove("hidden")

    // Focus the fill-all input if available
    const fillInput = this.step2Target?.querySelector("[data-inventory-grid-target='fillInput']")
    if (fillInput) fillInput.focus()
  }
}
