import { Controller } from "@hotwired/stimulus"

// Mobile sidebar controller
//
// Handles opening/closing the mobile sidebar overlay
// Prevents body scroll when sidebar is open
// Used for: mobile navigation menu
//
// Targets:
//   - overlay: The mobile sidebar overlay element
//
// Actions:
//   - toggle: Toggle mobile sidebar open/closed
//   - open: Show mobile sidebar
//   - close: Hide mobile sidebar
//
// Usage:
//   <div data-controller="mobile-sidebar">
//     <button data-action="click->mobile-sidebar#toggle">Toggle menu</button>
//     <div data-mobile-sidebar-target="overlay" class="hidden">
//       <!-- Sidebar content -->
//       <button data-action="click->mobile-sidebar#close">Close</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["overlay"]

  // Toggle mobile sidebar open/closed state
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
  }

  // Close mobile sidebar
  //
  // Hides overlay and restores body scroll
  close() {
    this.overlayTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }

  // Clean up when controller disconnects
  //
  // Ensures body scroll is restored if component is removed while open
  disconnect() {
    document.body.style.overflow = ""
  }
}
