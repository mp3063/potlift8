import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    reorderUrl: String,
    handle: { type: String, default: null }
  }

  connect() {
    console.log("Asset reorder controller connected")
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
      console.log("Asset reorder controller disconnected")
    }
  }

  initializeSortable() {
    if (!this.hasContainerTarget) {
      console.warn("Asset reorder controller: container target not found")
      return
    }

    if (!this.reorderUrlValue) {
      console.error("Asset reorder controller: reorderUrl value is required")
      return
    }

    const options = {
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      chosenClass: "sortable-chosen",
      forceFallback: true,
      fallbackClass: "sortable-fallback",
      onEnd: this.handleReorder.bind(this),
      onStart: this.handleDragStart.bind(this)
    }

    if (this.handleValue) {
      options.handle = this.handleValue
    }

    this.sortable = Sortable.create(this.containerTarget, options)

    console.log("Sortable initialized with options:", options)
  }

  handleDragStart(event) {
    event.item.classList.add("opacity-50")
  }

  handleReorder(event) {
    event.item.classList.remove("opacity-50")

    const assetIds = Array.from(this.containerTarget.children)
      .map(element => element.dataset.assetId)
      .filter(id => id)

    if (assetIds.length === 0) {
      console.warn("No asset IDs found for reordering")
      return
    }

    console.log("Reordering assets:", assetIds)

    this.showLoadingState()

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      this.showErrorState("Failed to reorder assets. Please refresh and try again.")
      return
    }

    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ asset_ids: assetIds })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log("Reorder successful:", data)
      this.showSuccessState(data.message || "Assets reordered successfully")
      this.updatePositionIndicators()
    })
    .catch(error => {
      console.error("Error reordering assets:", error)
      this.showErrorState("Failed to reorder assets. Please try again.")

    })
  }

  updatePositionIndicators() {
    const indicators = this.containerTarget.querySelectorAll(".position-indicator")
    indicators.forEach((indicator, index) => {
      indicator.textContent = index + 1
    })

    const items = this.containerTarget.children
    Array.from(items).forEach((item, index) => {
      item.dataset.position = index + 1
    })
  }

  showLoadingState() {
    this.containerTarget.classList.add("opacity-50", "pointer-events-none")
    this.containerTarget.setAttribute("aria-busy", "true")

    if (this.sortable) {
      this.sortable.option("disabled", true)
    }
  }

  hideLoadingState() {
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none")
    this.containerTarget.setAttribute("aria-busy", "false")

    if (this.sortable) {
      this.sortable.option("disabled", false)
    }
  }

  showSuccessState(message) {
    this.hideLoadingState()
    this.showFlashMessage(message, "success")
  }

  showErrorState(message) {
    this.hideLoadingState()
    this.showFlashMessage(message, "error")
  }

  showFlashMessage(message, type) {
    const flashContainer = document.getElementById("flash-messages")

    if (flashContainer) {
      const flashElement = document.createElement("div")
      flashElement.className = `flash-message flash-${type} mb-4 p-4 rounded-lg ${
        type === "success" ? "bg-green-50 text-green-800 border border-green-200" : "bg-red-50 text-red-800 border border-red-200"
      }`
      flashElement.setAttribute("role", type === "error" ? "alert" : "status")
      flashElement.setAttribute("aria-live", type === "error" ? "assertive" : "polite")

      flashElement.innerHTML = `
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${type === "success" ? `
              <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
              </svg>
            ` : `
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
              </svg>
            `}
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium">${this.escapeHtml(message)}</p>
          </div>
          <div class="ml-auto pl-3">
            <button type="button" class="inline-flex rounded-md p-1.5 ${
              type === "success" ? "text-green-500 hover:bg-green-100 focus:ring-green-600" : "text-red-500 hover:bg-red-100 focus:ring-red-600"
            } focus:outline-none focus:ring-2 focus:ring-offset-2" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      flashContainer.innerHTML = ""
      flashContainer.appendChild(flashElement)

      const dismissButton = flashElement.querySelector("button")
      dismissButton.addEventListener("click", () => {
        flashElement.remove()
      })

      setTimeout(() => {
        if (flashElement.parentNode) {
          flashElement.remove()
        }
      }, 3000)
    } else {
      // Fallback to fixed position flash message
      const flashElement = document.createElement("div")
      flashElement.className = `fixed top-20 right-4 z-50 max-w-sm rounded-md p-4 shadow-lg ${
        type === "success" ? "bg-green-50 border border-green-200" : "bg-red-50 border border-red-200"
      }`
      flashElement.setAttribute("role", type === "error" ? "alert" : "status")
      flashElement.setAttribute("aria-live", type === "error" ? "assertive" : "polite")

      flashElement.innerHTML = `
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${type === "success" ? `
              <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
              </svg>
            ` : `
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
              </svg>
            `}
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium ${type === "success" ? "text-green-800" : "text-red-800"}">
              ${this.escapeHtml(message)}
            </p>
          </div>
          <div class="ml-auto pl-3">
            <button type="button" class="inline-flex rounded-md p-1.5 ${
              type === "success" ? "text-green-500 hover:bg-green-100 focus:ring-green-600" : "text-red-500 hover:bg-red-100 focus:ring-red-600"
            } focus:outline-none focus:ring-2 focus:ring-offset-2" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      document.body.appendChild(flashElement)

      const dismissButton = flashElement.querySelector("button")
      dismissButton.addEventListener("click", () => {
        flashElement.remove()
      })

      setTimeout(() => {
        if (flashElement.parentNode) {
          flashElement.remove()
        }
      }, 3000)
    }
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
