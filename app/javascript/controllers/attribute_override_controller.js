import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["attributeSelect", "valueInput", "productValueHint"]
  static values = { productId: Number }

  async loadProductValue() {
    const selectedOption = this.attributeSelectTarget.selectedOptions[0]

    if (!selectedOption || !selectedOption.value) {
      this.clearValueInput()
      return
    }

    const attributeCode = selectedOption.dataset.code

    if (!attributeCode) {
      console.warn("No attribute code found for selected option")
      this.clearValueInput()
      return
    }

    try {
      const response = await fetch(`/products/${this.productIdValue}/attribute_value?code=${attributeCode}`, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      if (data.value) {
        this.valueInputTarget.value = data.value
        this.productValueHintTarget.textContent = `Product value: ${data.value}`
        this.productValueHintTarget.classList.remove("text-gray-500")
        this.productValueHintTarget.classList.add("text-blue-600")
      } else {
        this.valueInputTarget.value = ""
        this.productValueHintTarget.textContent = "No product value set for this attribute"
        this.productValueHintTarget.classList.remove("text-blue-600")
        this.productValueHintTarget.classList.add("text-gray-500")
      }
    } catch (error) {
      console.error("Failed to load product attribute value:", error)
      this.productValueHintTarget.textContent = "Failed to load product value"
      this.productValueHintTarget.classList.remove("text-blue-600")
      this.productValueHintTarget.classList.add("text-red-600")
    }
  }

  clearValueInput() {
    this.valueInputTarget.value = ""
    this.productValueHintTarget.textContent = ""
  }
}
