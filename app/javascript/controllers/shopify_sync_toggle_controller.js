import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "fields"]

  toggle() {
    this.fieldsTarget.classList.toggle("hidden", !this.checkboxTarget.checked)
    if (!this.checkboxTarget.checked) {
      // Clear metafield fields when unchecked
      this.fieldsTarget.querySelectorAll("input, select").forEach(el => {
        if (el.type !== "checkbox") el.value = ""
      })
    }
  }
}
