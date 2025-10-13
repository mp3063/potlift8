import { Controller } from "@hotwired/stimulus"

// Dropdown menu controller
//
// Handles opening/closing dropdown menus with outside click detection
// Used for: user menu, company selector, and other dropdown menus
//
// Targets:
//   - menu: The dropdown menu element to show/hide
//
// Actions:
//   - toggle: Toggle dropdown open/closed state
//   - open: Open the dropdown
//   - close: Close the dropdown
//
// Usage:
//   <div data-controller="dropdown">
//     <button data-action="click->dropdown#toggle">Toggle</button>
//     <div data-dropdown-target="menu" class="hidden">Menu content</div>
//   </div>
//
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.handleClickOutside = this.handleClickOutside.bind(this)
  }

  // Toggle dropdown open/closed state
  //
  // @param {Event} event - Click event
  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  // Open the dropdown menu
  open() {
    this.menuTarget.classList.remove("hidden")

    // Update ARIA expanded state
    const button = this.element.querySelector('[aria-expanded]')
    if (button) {
      button.setAttribute('aria-expanded', 'true')
    }

    // Listen for clicks outside to close
    document.addEventListener("click", this.handleClickOutside)
  }

  // Close the dropdown menu
  close() {
    this.menuTarget.classList.add("hidden")

    // Update ARIA expanded state
    const button = this.element.querySelector('[aria-expanded]')
    if (button) {
      button.setAttribute('aria-expanded', 'false')
    }

    // Stop listening for outside clicks
    document.removeEventListener("click", this.handleClickOutside)
  }

  // Handle clicks outside the dropdown to close it
  //
  // @param {Event} event - Click event
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  // Clean up event listeners when controller disconnects
  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }
}
