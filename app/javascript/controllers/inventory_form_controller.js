import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["valueInput", "etaQuantityInput", "etaDateInput", "totalAvailable"]

  connect() {
    console.log("Inventory form controller connected")
    this.updateTotalAvailable()
  }

  // Update total available whenever inputs change
  valueInputTargetConnected() {
    this.valueInputTarget.addEventListener('input', () => this.updateTotalAvailable())
  }

  etaQuantityInputTargetConnected() {
    this.etaQuantityInputTarget.addEventListener('input', () => this.updateTotalAvailable())
  }

  updateTotalAvailable() {
    const onHand = parseInt(this.valueInputTarget.value) || 0
    const etaQuantity = parseInt(this.etaQuantityInputTarget.value) || 0
    const total = onHand + etaQuantity

    if (this.hasTotalAvailableTarget) {
      this.totalAvailableTarget.textContent = total
    }
  }

  submit(event) {
    event.preventDefault()
    console.log("=== Submit button clicked ===")

    const form = document.getElementById('adjust-inventory-form')
    if (!form) {
      console.error("Form not found!")
      return
    }

    console.log("Form element:", form)
    console.log("Form action:", form.action)
    console.log("Form method:", form.method)
    console.log("Form has Turbo:", form.hasAttribute('data-turbo'))

    const formData = new FormData(form)
    console.log("Form data:")
    for (let [key, value] of formData.entries()) {
      console.log(`  ${key}: ${value}`)
    }

    console.log("Submitting form via Turbo...")
    try {
      form.requestSubmit()
      console.log("Form submitted successfully")
    } catch (error) {
      console.error("Error submitting form:", error)
    }
  }
}
