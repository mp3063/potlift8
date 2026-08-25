import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display"]

  updateHex() {
    if (this.hasDisplayTarget && this.hasInputTarget) {
      this.displayTarget.textContent = this.inputTarget.value
    }
  }
}
