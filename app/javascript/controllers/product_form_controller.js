import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sku", "productType", "configurationTypeContainer", "configurationType"]

  async validateSku(event) {
    const sku = event.target.value.trim()

    if (sku === "") {
      this.clearSkuError()
      return
    }

    try {
      const response = await fetch(`/products/validate_sku?sku=${encodeURIComponent(sku)}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (!response.ok) {
        console.error("SKU validation request failed:", response.status)
        return
      }

      const data = await response.json()

      if (!data.valid) {
        this.showSkuError(data.message || "SKU already exists")
      } else {
        this.clearSkuError()
      }
    } catch (error) {
      console.error("SKU validation error:", error)
      // Don't show error to user for network failures
    }
  }

  handleTypeChange(event) {
    const productType = event.target.value

    if (this.hasConfigurationTypeContainerTarget) {
      if (productType === "configurable") {
        this.configurationTypeContainerTarget.classList.remove("hidden")
      } else {
        this.configurationTypeContainerTarget.classList.add("hidden")
        if (this.hasConfigurationTypeTarget) {
          this.configurationTypeTarget.value = ""
        }
      }
    }
  }

  showSkuError(message) {
    const skuField = this.skuTarget

    skuField.classList.add("border-red-300", "focus:border-red-500", "focus:ring-red-500")
    skuField.classList.remove("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
    skuField.setAttribute("aria-invalid", "true")

    let errorEl = skuField.parentElement.querySelector(".sku-error")
    if (!errorEl) {
      errorEl = document.createElement("p")
      errorEl.className = "mt-2 text-sm text-red-600 sku-error"
      errorEl.setAttribute("role", "alert")

      const hintEl = skuField.parentElement.querySelector("#sku-description")
      if (hintEl) {
        hintEl.style.display = "none"
      }

      skuField.parentElement.appendChild(errorEl)
    }
    errorEl.textContent = message
  }

  clearSkuError() {
    const skuField = this.skuTarget

    skuField.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
    skuField.classList.add("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
    skuField.setAttribute("aria-invalid", "false")

    const errorEl = skuField.parentElement.querySelector(".sku-error")
    if (errorEl) {
      errorEl.remove()
    }

    const hintEl = skuField.parentElement.querySelector("#sku-description")
    if (hintEl) {
      hintEl.style.display = "block"
    }
  }

  get csrfToken() {
    const element = document.querySelector('meta[name="csrf-token"]')
    return element ? element.content : ""
  }
}
