import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggleMobile(event) {
    if (event) event.preventDefault()

    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden")

      const button = event.currentTarget
      const isExpanded = !this.panelTarget.classList.contains("hidden")
      button.setAttribute("aria-expanded", isExpanded)
    }
  }

  submit(event) {
    const submitButton = event.target.querySelector('button[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = "Applying..."

      setTimeout(() => {
        submitButton.disabled = false
        submitButton.textContent = "Apply Filters"
      }, 1000)
    }
  }
}
