import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectedCount", "submitButton", "form", "productList", "productRow", "selectAll", "count", "productCheckbox"]

  connect() {
    console.log('ProductSelectorController connected')
    console.log('Checkboxes found:', this.checkboxTargets.length)
    console.log('Has selectedCount target:', this.hasSelectedCountTarget)
    console.log('Has submitButton target:', this.hasSubmitButtonTarget)
    this.updateCount()
    this.updateSubmitButton()
  }

  selectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })

    this.updateCount()
  }

  deselectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })

    this.updateCount()
  }

  updateCount() {
    const selectedCount = this.selectedCheckboxes.length
    console.log('updateCount called, selectedCount:', selectedCount)

    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
      console.log('Updated selectedCountTarget to:', selectedCount)
    } else {
      console.warn('selectedCountTarget not found!')
    }

    if (this.hasCountTarget) {
      this.countTarget.textContent = selectedCount
    }

    this.updateSubmitButton()
  }

  updateSubmitButton() {
    if (!this.hasSubmitButtonTarget) {
      console.warn('updateSubmitButton: submitButtonTarget not found')
      return
    }

    const selectedCount = this.selectedCheckboxes.length
    const submitButton = this.submitButtonTarget
    const buttonElement = submitButton.querySelector('button') || submitButton

    console.log('updateSubmitButton: selectedCount:', selectedCount, 'buttonElement:', buttonElement)

    if (selectedCount === 0) {
      buttonElement.disabled = true
      buttonElement.classList.add('opacity-50', 'cursor-not-allowed')
      console.log('Submit button disabled')
    } else {
      buttonElement.disabled = false
      buttonElement.classList.remove('opacity-50', 'cursor-not-allowed')
      console.log('Submit button enabled')
    }
  }

  toggleAll(event) {
    const checked = event.target.checked
    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets

    targets.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateCount()
  }

  toggleProduct(event) {
    this.updateCount()
    this.updateSelectAllState()
  }

  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return

    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets
    const total = targets.length
    const checked = this.selectedCheckboxes.length

    if (checked === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checked === total) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
  }

  handleSearch(event) {
    if (event.target.tagName === 'SELECT') {
      event.target.form.requestSubmit()
    }
  }

  get selectedCheckboxes() {
    const targets = this.hasProductCheckboxTarget ? this.productCheckboxTargets : this.checkboxTargets
    return targets.filter(checkbox => checkbox.checked)
  }

  get selectedProductIds() {
    return this.selectedCheckboxes.map(checkbox => checkbox.value)
  }
}
