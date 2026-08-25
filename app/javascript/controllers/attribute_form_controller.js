import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "paType", "viewFormat", "optionsSection"]

  connect() {
    this.handleTypeChange()
    this.handleFormatChange()
  }

  async validateCode(event) {
    const code = event.target.value.trim()

    if (code === "") return

    if (!/^[a-z0-9_]+$/.test(code)) {
      this.showCodeError("Code must contain only lowercase letters, numbers, and underscores")
      return
    }

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

  handleTypeChange() {
    if (!this.hasPaTypeTarget) return

    const paType = this.paTypeTarget.value

    if (paType === 'patype_select' || paType === 'patype_multiselect') {
      this.showOptionsSection()
    } else {
      this.hideOptionsSection()
    }
  }

  handleFormatChange() {
    if (!this.hasViewFormatTarget) return

    const format = this.viewFormatTarget.value

  }

  showOptionsSection() {
    if (!this.hasOptionsSectionTarget) return
    this.optionsSectionTarget.classList.remove('hidden')
  }

  hideOptionsSection() {
    if (!this.hasOptionsSectionTarget) return
    this.optionsSectionTarget.classList.add('hidden')
  }

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

  clearCodeError() {
    const codeField = this.codeTarget
    codeField.classList.remove("border-red-300")

    const errorEl = codeField.parentElement.querySelector(".code-error")
    if (errorEl) errorEl.remove()
  }
}
