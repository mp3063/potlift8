import { Controller } from "@hotwired/stimulus"

// Click-to-edit controller for individual inventory cells in the storage view.
// Click display value → show input → Enter/blur saves via Turbo PATCH.
export default class extends Controller {
  static targets = ["display", "input"]

  edit() {
    if (this.hasDisplayTarget) this.displayTarget.classList.add("hidden")
    if (this.hasInputTarget) {
      this.inputTarget.classList.remove("hidden")
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  save() {
    if (this.hasInputTarget) {
      const form = this.inputTarget.closest("form")
      if (form) form.requestSubmit()
    }
  }

  cancel() {
    if (this.hasInputTarget) {
      this.inputTarget.classList.add("hidden")
      this.inputTarget.value = this.displayTarget.textContent.trim().replace(/,/g, "")
    }
    if (this.hasDisplayTarget) this.displayTarget.classList.remove("hidden")
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }
}
