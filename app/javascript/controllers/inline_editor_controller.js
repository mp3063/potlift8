import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "editor", "form"]
  static values = {
    url: String
  }

  connect() {
    this.previousActiveElement = null
  }

  edit(event) {
    event.preventDefault()

    this.previousActiveElement = event.target

    this.displayTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")

    this.editorTarget.setAttribute("aria-hidden", "false")
    this.displayTarget.setAttribute("aria-hidden", "true")

    setTimeout(() => {
      const firstInput = this.editorTarget.querySelector(
        "input:not([type=hidden]), select, textarea"
      )
      if (firstInput) {
        firstInput.focus()

        if (firstInput.tagName === "INPUT" &&
            (firstInput.type === "text" || firstInput.type === "number")) {
          firstInput.select()
        }
      }
    }, 10)

    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }

  cancel(event) {
    if (event) event.preventDefault()

    if (this.hasFormTarget) {
      this.formTarget.reset()
    }

    this.editorTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")

    this.editorTarget.setAttribute("aria-hidden", "true")
    this.displayTarget.setAttribute("aria-hidden", "false")

    if (this.previousActiveElement) {
      this.previousActiveElement.focus()
      this.previousActiveElement = null
    }

    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }
  }

  handleSubmit(event) {
    const { success, fetchResponse } = event.detail

    if (success) {

      this.editorTarget.classList.add("hidden")
      this.displayTarget.classList.remove("hidden")

      this.editorTarget.setAttribute("aria-hidden", "true")
      this.displayTarget.setAttribute("aria-hidden", "false")

      if (this.previousActiveElement) {
        this.previousActiveElement.focus()
        this.previousActiveElement = null
      }

      if (this.escapeHandler) {
        document.removeEventListener("keydown", this.escapeHandler)
        this.escapeHandler = null
      }

      this.showSuccessFeedback()
    } else {
      this.showErrorFeedback()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }

  showSuccessFeedback() {
    this.displayTarget.classList.add("bg-green-50", "ring-2", "ring-green-500", "rounded", "p-1", "-m-1")

    // Announce to screen readers
    this.announceToScreenReader("Attribute value updated successfully")

    setTimeout(() => {
      this.displayTarget.classList.remove("bg-green-50", "ring-2", "ring-green-500", "rounded", "p-1", "-m-1")
    }, 1000)
  }

  showErrorFeedback() {
    this.editorTarget.classList.add("ring-2", "ring-red-500", "rounded", "p-2", "-m-2")

    // Announce to screen readers
    this.announceToScreenReader("Failed to update attribute value. Please check the form for errors.")

    const errorInput = this.editorTarget.querySelector("input[aria-invalid=true], .field_with_errors input")
    if (errorInput) {
      errorInput.focus()
    }

    setTimeout(() => {
      this.editorTarget.classList.remove("ring-2", "ring-red-500", "rounded", "p-2", "-m-2")
    }, 3000)
  }

  announceToScreenReader(message) {
    const announcement = document.createElement("div")
    announcement.setAttribute("role", "status")
    announcement.setAttribute("aria-live", "polite")
    announcement.className = "sr-only"
    announcement.textContent = message

    document.body.appendChild(announcement)

    setTimeout(() => {
      announcement.remove()
    }, 1000)
  }

  disconnect() {
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }
  }
}
