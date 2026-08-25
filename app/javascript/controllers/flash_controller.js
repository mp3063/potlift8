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
    this.timeouts = []

    // Calculate timeout based on message length for each message
    // Formula: minimum 5s, +1s per 10 words (average reading speed ~200 words/min)
    this.messageTargets.forEach((message, index) => {
      const timeout = this.calculateTimeout(message)

      this.timeouts[index] = setTimeout(() => {
        this.fadeOut(message)
      }, timeout)
    })

    this.handleFlashEvent = this.handleFlashEvent.bind(this)
    window.addEventListener('flash:show', this.handleFlashEvent)
  }

  /**
   * Calculate dynamic timeout based on message length
   * Formula: minimum 5s, +1s per 10 words
   */
  calculateTimeout(message) {
    const text = message.textContent || ''
    const wordCount = text.trim().split(/\s+/).length
    return Math.max(5000, 5000 + (wordCount / 10) * 1000)
  }

  handleFlashEvent(event) {
    const { type, message } = event.detail
    this.show(type, message)
  }

  show(type, message) {
    if (!this.hasContainerTarget) {
      console.warn('Flash container not found')
      return
    }

    const flash = this.createFlashElement(type, message)
    this.containerTarget.appendChild(flash)

    const timeout = this.calculateTimeout(flash)
    setTimeout(() => {
      this.fadeOut(flash)
    }, timeout)
  }

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
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Manually dismiss a specific flash message
   * Clears associated timeout to prevent memory leaks
   */
  dismiss(event) {
    const button = event.currentTarget
    const message = button.closest("[data-flash-target='message']")
    if (message) {
      const index = this.messageTargets.indexOf(message)
      if (index !== -1 && this.timeouts && this.timeouts[index]) {
        clearTimeout(this.timeouts[index])
        this.timeouts[index] = null
      }
      this.fadeOut(message)
    }
  }

  dismissAll() {
    this.messageTargets.forEach(message => {
      this.fadeOut(message)
    })
  }

  fadeOut(element) {
    element.style.transition = "opacity 0.3s ease-out"
    element.style.opacity = "0"

    setTimeout(() => {
      element.remove()
    }, 300)
  }

  /**
   * Clean up all timeouts when controller disconnects
   * Prevents memory leaks from pending timeouts
   */
  disconnect() {
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
