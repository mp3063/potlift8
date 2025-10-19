import { Controller } from "@hotwired/stimulus"

/**
 * Attribute Override Controller
 *
 * Handles the "Add Attribute Override" modal functionality:
 * - Loads product attribute values via AJAX when attribute is selected
 * - Auto-populates the override value input with the inherited product value
 * - Shows helpful hint text with the product's current value
 *
 * @example
 *   <div data-controller="attribute-override" data-attribute-override-product-id-value="123">
 *     <select data-attribute-override-target="attributeSelect" data-action="change->attribute-override#loadProductValue">
 *       <option value="1" data-code="price">Price</option>
 *     </select>
 *     <input data-attribute-override-target="valueInput">
 *     <p data-attribute-override-target="productValueHint"></p>
 *   </div>
 */
export default class extends Controller {
  static targets = ["attributeSelect", "valueInput", "productValueHint"]
  static values = { productId: Number }

  /**
   * Load product value when attribute is selected
   * Fetches the product's current value for the selected attribute
   * and populates the override input
   */
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
      // Fetch product attribute value
      const response = await fetch(`/products/${this.productIdValue}/attribute_value?code=${attributeCode}`, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      // Auto-populate the value input with product value
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

  /**
   * Clear value input and hint
   */
  clearValueInput() {
    this.valueInputTarget.value = ""
    this.productValueHintTarget.textContent = ""
  }
}
