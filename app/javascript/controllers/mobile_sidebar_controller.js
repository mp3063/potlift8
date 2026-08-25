import { Controller } from "@hotwired/stimulus"

// Mobile sidebar controller
//
// Handles opening/closing the mobile sidebar overlay
// Prevents body scroll when sidebar is open
// Used for: mobile navigation menu
//
// Targets:
//   - overlay: The mobile sidebar overlay element
//   - menuButton: The button that toggles the sidebar
//
// Actions:
//   - toggle: Toggle mobile sidebar open/closed
//   - open: Show mobile sidebar
//   - close: Hide mobile sidebar
//   - handleKeydown: Handle keyboard events (Escape to close)
//
// Usage:
//   <div data-controller="mobile-sidebar">
//     <button data-action="click->mobile-sidebar#toggle"
//             data-mobile-sidebar-target="menuButton"
//             aria-expanded="false">Toggle menu</button>
//     <div data-mobile-sidebar-target="overlay" class="hidden">
//       <!-- Sidebar content -->
//       <button data-action="click->mobile-sidebar#close">Close</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["overlay", "menuButton"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  toggle() {
    if (this.overlayTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  // Open mobile sidebar
  //
  // Shows overlay and prevents body scroll
  open() {
    this.overlayTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    if (this.hasMenuButtonTarget) {
      this.menuButtonTarget.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    document.body.style.overflow = ""
    if (this.hasMenuButtonTarget) {
      this.menuButtonTarget.setAttribute("aria-expanded", "false")
      this.menuButtonTarget.focus()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.overlayTarget.classList.contains("hidden")) {
      this.close()
    }
  }

  disconnect() {
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }
}
