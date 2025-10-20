import { Controller } from "@hotwired/stimulus"

/**
 * Color Picker controller for synchronizing color input with hex display
 *
 * Handles real-time color value updates between:
 * - <input type="color"> (color picker)
 * - Text display showing current hex value
 *
 * @example
 *   <div data-controller="color-picker">
 *     <input type="color"
 *            data-color-picker-target="input"
 *            data-action="input->color-picker#updateHex">
 *     <span data-color-picker-target="display">#3b82f6</span>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "display"]

  /**
   * Update hex display when color picker value changes
   * Triggered on input event (fires during color selection)
   */
  updateHex() {
    if (this.hasDisplayTarget && this.hasInputTarget) {
      this.displayTarget.textContent = this.inputTarget.value
    }
  }
}
