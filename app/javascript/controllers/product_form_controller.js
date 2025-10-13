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
  static targets = ["sku", "productType"]

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
   * Future enhancement: Could show/hide type-specific fields
   *
   * @param {Event} event - Change event from product type select
   */
  handleTypeChange(event) {
    const typeId = event.target.value

    // Log for debugging
    console.log("Product type changed to:", typeId)

    // Future: Show/hide configuration type selector for configurable products
    // Future: Show/hide bundle composition UI for bundle products
  }

  /**
   * Display SKU validation error
   *
   * @param {string} message - Error message to display
   */
  showSkuError(message) {
    const skuField = this.skuTarget

    // Add error styling to input field
    skuField.classList.add("ring-red-300", "focus:ring-red-600")
    skuField.classList.remove("ring-gray-300", "focus:ring-indigo-600")
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
    skuField.classList.remove("ring-red-300", "focus:ring-red-600")
    skuField.classList.add("ring-gray-300", "focus:ring-indigo-600")
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
