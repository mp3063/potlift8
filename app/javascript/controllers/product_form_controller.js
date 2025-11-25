import { Controller } from "@hotwired/stimulus"

/**
 * Product Form Controller
 *
 * Handles product form interactions:
 * - SKU validation (async check for uniqueness)
 * - Product type change handling
 * - Form state management
 *
 * Targets:
 * - sku: SKU input field
 * - productType: Product type select field
 *
 * Actions:
 * - validateSku: Triggered on SKU field blur
 * - handleTypeChange: Triggered on product type change
 */
export default class extends Controller {
  static targets = ["sku", "productType", "configurationTypeContainer", "configurationType"]

  /**
   * Validate SKU uniqueness via async API call
   *
   * @param {Event} event - Blur event from SKU field
   */
  async validateSku(event) {
    const sku = event.target.value.trim()

    // Skip validation if SKU is empty (will be auto-generated)
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

  /**
   * Handle product type selection change
   *
   * Shows/hides the configuration type field based on product type.
   * Configuration type is only required for "configurable" products.
   *
   * @param {Event} event - Change event from product type select
   */
  handleTypeChange(event) {
    const productType = event.target.value

    // Show configuration type selector only for configurable products
    if (this.hasConfigurationTypeContainerTarget) {
      if (productType === "configurable") {
        this.configurationTypeContainerTarget.classList.remove("hidden")
      } else {
        this.configurationTypeContainerTarget.classList.add("hidden")
        // Clear configuration type when switching away from configurable
        if (this.hasConfigurationTypeTarget) {
          this.configurationTypeTarget.value = ""
        }
      }
    }
  }

  /**
   * Display SKU validation error
   *
   * @param {string} message - Error message to display
   */
  showSkuError(message) {
    const skuField = this.skuTarget

    // Add error styling to input field
    skuField.classList.add("border-red-300", "focus:border-red-500", "focus:ring-red-500")
    skuField.classList.remove("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
    skuField.setAttribute("aria-invalid", "true")

    // Find or create error message element
    let errorEl = skuField.parentElement.querySelector(".sku-error")
    if (!errorEl) {
      errorEl = document.createElement("p")
      errorEl.className = "mt-2 text-sm text-red-600 sku-error"
      errorEl.setAttribute("role", "alert")

      // Remove the description hint if present
      const hintEl = skuField.parentElement.querySelector("#sku-description")
      if (hintEl) {
        hintEl.style.display = "none"
      }

      skuField.parentElement.appendChild(errorEl)
    }
    errorEl.textContent = message
  }

  /**
   * Clear SKU validation error
   */
  clearSkuError() {
    const skuField = this.skuTarget

    // Remove error styling from input field
    skuField.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
    skuField.classList.add("border-gray-300", "focus:border-blue-500", "focus:ring-blue-500")
    skuField.setAttribute("aria-invalid", "false")

    // Remove error message element
    const errorEl = skuField.parentElement.querySelector(".sku-error")
    if (errorEl) {
      errorEl.remove()
    }

    // Show the description hint again
    const hintEl = skuField.parentElement.querySelector("#sku-description")
    if (hintEl) {
      hintEl.style.display = "block"
    }
  }

  /**
   * Get CSRF token for API requests
   *
   * @returns {string} CSRF token from meta tag
   */
  get csrfToken() {
    const element = document.querySelector('meta[name="csrf-token"]')
    return element ? element.content : ""
  }
}
