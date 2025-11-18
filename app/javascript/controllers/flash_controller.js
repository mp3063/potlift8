import { Controller } from "@hotwired/stimulus"

// Flash message controller
//
// Handles flash message auto-dismiss and manual dismissal
// Features:
//   - Dynamic auto-dismiss timing based on message length (WCAG 2.2.1 compliance)
//   - Formula: minimum 5s, +1s per 10 words (average reading speed ~200 words/min)
//   - Smooth fade-out animation
//   - Manual dismiss button
//   - Dynamic flash message creation via custom events
//
// Targets:
//   - message: Individual flash message elements
//   - container: Container for flash messages
//
// Actions:
//   - dismiss: Manually dismiss a specific flash message
//
// Custom Events:
//   - flash:show - Show a new flash message
//     detail: { type: 'success'|'error'|'warning'|'info', message: string }
//
// Usage:
//   <div data-controller="flash" data-flash-target="container">
//     <div data-flash-target="message">
//       <p>Your message</p>
//       <button data-action="click->flash#dismiss">Dismiss</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["message", "container"]

  connect() {
    // Initialize timeout storage
    this.timeouts = []

    // Calculate timeout based on message length for each message
    // Formula: minimum 5s, +1s per 10 words (average reading speed ~200 words/min)
    this.messageTargets.forEach((message, index) => {
      const timeout = this.calculateTimeout(message)

      // Store timeout ID for cleanup
      this.timeouts[index] = setTimeout(() => {
        this.fadeOut(message)
      }, timeout)
    })

    // Listen for custom flash events
    this.handleFlashEvent = this.handleFlashEvent.bind(this)
    window.addEventListener('flash:show', this.handleFlashEvent)
  }

  /**
   * Calculate dynamic timeout based on message length
   * Formula: minimum 5s, +1s per 10 words
   * @param {HTMLElement} message - Flash message element
   * @returns {number} Timeout in milliseconds
   */
  calculateTimeout(message) {
    const text = message.textContent || ''
    const wordCount = text.trim().split(/\s+/).length
    return Math.max(5000, 5000 + (wordCount / 10) * 1000)
  }

  /**
   * Handle custom flash:show events
   * @param {CustomEvent} event - Event with detail: { type, message }
   */
  handleFlashEvent(event) {
    const { type, message } = event.detail
    this.show(type, message)
  }

  /**
   * Dynamically show a flash message
   * @param {string} type - Message type: success, error, warning, info
   * @param {string} message - Message text
   */
  show(type, message) {
    if (!this.hasContainerTarget) {
      console.warn('Flash container not found')
      return
    }

    // Create flash message element
    const flash = this.createFlashElement(type, message)
    this.containerTarget.appendChild(flash)

    // Auto-dismiss with dynamic timeout based on message length
    const timeout = this.calculateTimeout(flash)
    setTimeout(() => {
      this.fadeOut(flash)
    }, timeout)
  }

  /**
   * Create a flash message element
   * @param {string} type - Message type
   * @param {string} message - Message text
   * @returns {HTMLElement} Flash message element
   */
  createFlashElement(type, message) {
    const colors = {
      success: 'bg-green-50 border-green-200 text-green-800',
      error: 'bg-red-50 border-red-200 text-red-800',
      warning: 'bg-yellow-50 border-yellow-200 text-yellow-800',
      info: 'bg-blue-50 border-blue-200 text-blue-800'
    }

    const icons = {
      success: '✓',
      error: '✕',
      warning: '⚠',
      info: 'ℹ'
    }

    const colorClass = colors[type] || colors.info
    const icon = icons[type] || icons.info

    const div = document.createElement('div')
    div.setAttribute('data-flash-target', 'message')
    div.className = `${colorClass} border rounded-lg p-4 mb-3 flex items-center justify-between shadow-sm`
    div.innerHTML = `
      <div class="flex items-center">
        <span class="font-bold mr-2">${icon}</span>
        <p class="text-sm">${this.escapeHtml(message)}</p>
      </div>
      <button
        data-action="click->flash#dismiss"
        class="text-gray-500 hover:text-gray-700 ml-4"
        aria-label="Dismiss notification"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </button>
    `
    return div
  }

  /**
   * Escape HTML to prevent XSS
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Manually dismiss a specific flash message
   * Clears associated timeout to prevent memory leaks
   * @param {Event} event - Click event on dismiss button
   */
  dismiss(event) {
    // Use currentTarget to always start from the button element, not the clicked SVG/path
    const button = event.currentTarget
    const message = button.closest("[data-flash-target='message']")
    if (message) {
      // Clear timeout if it exists
      const index = this.messageTargets.indexOf(message)
      if (index !== -1 && this.timeouts && this.timeouts[index]) {
        clearTimeout(this.timeouts[index])
        this.timeouts[index] = null
      }
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

  /**
   * Clean up all timeouts when controller disconnects
   * Prevents memory leaks from pending timeouts
   */
  disconnect() {
    // Clear all pending timeouts
    if (this.timeouts) {
      this.timeouts.forEach(timeout => {
        if (timeout) {
          clearTimeout(timeout)
        }
      })
      this.timeouts = []
    }
    window.removeEventListener('flash:show', this.handleFlashEvent)
  }
}
