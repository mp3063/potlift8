import { Controller } from "@hotwired/stimulus"

/**
 * Attribute Form Controller
 *
 * Handles form interactions for product attributes:
 * - View format changes (show/hide options section)
 * - Attribute type changes
 * - Inline code validation
 * - Dynamic form field visibility
 *
 * Targets:
 *   code: Code input field
 *   paType: Attribute type select field
 *   viewFormat: View format select field
 *   optionsSection: Options section (for select/multiselect)
 */
export default class extends Controller {
  static targets = ["code", "paType", "viewFormat", "optionsSection"]

  connect() {
    // Initialize form state on load
    this.handleTypeChange()
    this.handleFormatChange()
  }

  /**
   * Validates attribute code on blur
   * - Checks format (lowercase, numbers, underscores only)
   * - Checks uniqueness via API
   */
  async validateCode(event) {
    const code = event.target.value.trim()

    if (code === "") return

    // Validate format
    if (!/^[a-z0-9_]+$/.test(code)) {
      this.showCodeError("Code must contain only lowercase letters, numbers, and underscores")
      return
    }

    // Check uniqueness
    try {
      const attributeId = event.target.dataset.attributeId
      let url = `/product_attributes/validate_code?code=${encodeURIComponent(code)}`
      if (attributeId) {
        url += `&id=${attributeId}`
      }

      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      const data = await response.json()

      if (!data.valid) {
        this.showCodeError(data.message || "Code already exists")
      } else {
        this.clearCodeError()
      }
    } catch (error) {
      console.error("Code validation error:", error)
    }
  }

  /**
   * Handles attribute type changes
   * - Can be used to show/hide type-specific fields
   */
  handleTypeChange() {
    if (!this.hasPaTypeTarget) return

    const paType = this.paTypeTarget.value

    // Show/hide options section for select types
    if (paType === 'patype_select' || paType === 'patype_multiselect') {
      this.showOptionsSection()
    } else {
      this.hideOptionsSection()
    }
  }

  /**
   * Handles view format changes
   * - Shows options section for select/multiselect formats
   */
  handleFormatChange() {
    if (!this.hasViewFormatTarget) return

    const format = this.viewFormatTarget.value

    // Options section is shown based on pa_type, not view_format
    // But we keep this method for potential future use
  }

  /**
   * Shows the options section for select/multiselect
   */
  showOptionsSection() {
    if (!this.hasOptionsSectionTarget) return
    this.optionsSectionTarget.classList.remove('hidden')
  }

  /**
   * Hides the options section
   */
  hideOptionsSection() {
    if (!this.hasOptionsSectionTarget) return
    this.optionsSectionTarget.classList.add('hidden')
  }

  /**
   * Shows validation error for code field
   */
  showCodeError(message) {
    const codeField = this.codeTarget
    codeField.classList.add("border-red-300")

    let errorEl = codeField.parentElement.querySelector(".code-error")
    if (!errorEl) {
      errorEl = document.createElement("p")
      errorEl.className = "mt-2 text-sm text-red-600 code-error"
      codeField.parentElement.appendChild(errorEl)
    }
    errorEl.textContent = message
  }

  /**
   * Clears code field validation error
   */
  clearCodeError() {
    const codeField = this.codeTarget
    codeField.classList.remove("border-red-300")

    const errorEl = codeField.parentElement.querySelector(".code-error")
    if (errorEl) errorEl.remove()
  }
}
