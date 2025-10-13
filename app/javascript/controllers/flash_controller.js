import { Controller } from "@hotwired/stimulus"

// Flash message controller
//
// Handles flash message auto-dismiss and manual dismissal
// Features:
//   - Auto-dismiss after 5 seconds
//   - Smooth fade-out animation
//   - Manual dismiss button
//
// Targets:
//   - message: Individual flash message elements
//
// Actions:
//   - dismiss: Manually dismiss a specific flash message
//
// Usage:
//   <div data-controller="flash">
//     <div data-flash-target="message">
//       <p>Your message</p>
//       <button data-action="click->flash#dismiss">Dismiss</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-dismiss all messages after 5 seconds
    this.timeout = setTimeout(() => {
      this.dismissAll()
    }, 5000)
  }

  // Manually dismiss a specific flash message
  //
  // @param {Event} event - Click event on dismiss button
  dismiss(event) {
    const message = event.target.closest("[data-flash-target='message']")
    if (message) {
      this.fadeOut(message)
    }
  }

  // Dismiss all flash messages
  dismissAll() {
    this.messageTargets.forEach(message => {
      this.fadeOut(message)
    })
  }

  // Fade out and remove a message element
  //
  // @param {HTMLElement} element - Flash message element to remove
  fadeOut(element) {
    // Add fade-out transition
    element.style.transition = "opacity 0.3s ease-out"
    element.style.opacity = "0"

    // Remove element after transition completes
    setTimeout(() => {
      element.remove()
    }, 300)
  }

  // Clean up timeout when controller disconnects
  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
