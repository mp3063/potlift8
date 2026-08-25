import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "labelCheckbox",
    "labelRow",
    "selectedLabelCount",
    "productIds",
    "actionType",
    "submitButton"
  ]

  connect() {
    this.labelCheckboxTargets.forEach(checkbox => {
      checkbox.addEventListener("change", () => this.updateLabelCount())
    })

    this.updateLabelCount()

    this.currentProductIds = []

    this.labelData = null
  }

  updateLabelCount() {
    const count = this.getSelectedLabels().length
    if (this.hasSelectedLabelCountTarget) {
      this.selectedLabelCountTarget.textContent = count
    }

    if (this.hasSubmitButtonTarget) {
      const button = this.submitButtonTarget.querySelector("button")
      if (button) {
        button.disabled = count === 0
        if (count === 0) {
          button.classList.add("opacity-50", "cursor-not-allowed")
        } else {
          button.classList.remove("opacity-50", "cursor-not-allowed")
        }
      }
    }
  }

  getSelectedLabels() {
    return this.labelCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  clearLabels() {
    this.labelCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateLabelCount()
  }

  setProductIds(productIds) {
    if (!this.hasProductIdsTarget) return

    this.currentProductIds = productIds

    this.labelData = null

    while (this.productIdsTarget.firstChild) {
      this.productIdsTarget.removeChild(this.productIdsTarget.firstChild)
    }

    productIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "product_ids[]"
      input.value = id
      this.productIdsTarget.appendChild(input)
    })

    const addRadio = this.actionTypeTargets.find(r => r.value === "add")
    if (addRadio) {
      addRadio.checked = true
    }
    this.clearLabels()
    this.filterLabelsForAdd()
  }

  async handleActionTypeChange(event) {
    const actionType = event.target.value

    this.clearLabels()

    if (actionType === "remove") {
      await this.filterLabelsForRemove()
    } else {
      await this.filterLabelsForAdd()
    }
  }

  async fetchLabelData() {
    if (this.labelData !== null) {
      return this.labelData
    }

    if (this.currentProductIds.length === 0) {
      this.labelData = {
        assigned_to_any: new Set(),
        assigned_to_all: new Set()
      }
      return this.labelData
    }

    try {
      const params = new URLSearchParams()
      this.currentProductIds.forEach(id => params.append("product_ids[]", id))

      const response = await fetch(`/products/bulk/labels_for_products?${params}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error("Failed to fetch labels")
      }

      const data = await response.json()
      this.labelData = {
        assigned_to_any: new Set(data.assigned_to_any.map(id => id.toString())),
        assigned_to_all: new Set(data.assigned_to_all.map(id => id.toString()))
      }
      return this.labelData
    } catch (error) {
      console.error("Error fetching labels for products:", error)
      this.labelData = {
        assigned_to_any: new Set(),
        assigned_to_all: new Set()
      }
      return this.labelData
    }
  }

  async filterLabelsForAdd() {
    const data = await this.fetchLabelData()

    this.labelCheckboxTargets.forEach(checkbox => {
      const labelId = checkbox.value
      const labelRow = checkbox.closest("label")

      if (data.assigned_to_all.has(labelId)) {
        labelRow.classList.add("hidden")
        checkbox.checked = false
      } else {
        labelRow.classList.remove("hidden")
      }
    })

    this.updateLabelCount()
  }

  async filterLabelsForRemove() {
    const data = await this.fetchLabelData()

    this.labelCheckboxTargets.forEach(checkbox => {
      const labelId = checkbox.value
      const labelRow = checkbox.closest("label")

      if (data.assigned_to_any.has(labelId)) {
        labelRow.classList.remove("hidden")
      } else {
        labelRow.classList.add("hidden")
        checkbox.checked = false
      }
    })

    this.updateLabelCount()
  }

  /**
   * Show all labels (fallback)
   */
  showAllLabels() {
    this.labelCheckboxTargets.forEach(checkbox => {
      const labelRow = checkbox.closest("label")
      labelRow.classList.remove("hidden")
    })
  }

  getActionType() {
    const checkedRadio = this.actionTypeTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value : "add"
  }

  submit(event) {
    const selectedLabels = this.getSelectedLabels()
    const actionType = this.getActionType()

    if (selectedLabels.length === 0) {
      event.preventDefault()
      alert("Please select at least one label")
      return
    }

    const actionInput = document.createElement("input")
    actionInput.type = "hidden"
    actionInput.name = "action_type"
    actionInput.value = actionType
    this.formTarget.appendChild(actionInput)

  }
}
