import { Controller } from "@hotwired/stimulus"

// Global search controller
//
// Handles keyboard shortcuts for global search
// Features:
//   - ⌘K (Mac) / Ctrl+K (Windows/Linux) to focus search input
//   - ESC to blur search input
//
// Targets:
//   - input: The search input field
//
// Actions:
//   - handleKeydown: Handle keyboard events
//
// Usage:
//   <form data-controller="global-search">
//     <input
//       data-global-search-target="input"
//       data-action="keydown->global-search#handleKeydown"
//     >
//   </form>
//
export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Listen for global keyboard shortcuts
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener("keydown", this.handleGlobalKeydown)
  }

  // Handle keyboard events on search input
  //
  // @param {KeyboardEvent} event - Keyboard event
  handleKeydown(event) {
    // ESC to blur/clear search
    if (event.key === "Escape") {
      this.inputTarget.blur()
    }
  }

  // Handle global keyboard shortcuts
  //
  // @param {KeyboardEvent} event - Keyboard event
  handleGlobalKeydown(event) {
    // ⌘K (Mac) or Ctrl+K (Windows/Linux) to focus search
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  // Clean up event listeners when controller disconnects
  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
  }
}
