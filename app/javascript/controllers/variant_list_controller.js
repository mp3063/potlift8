import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["tbody"]

  connect() {
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeSortable() {
    if (!this.hasTbodyTarget) return

    this.sortable = Sortable.create(this.tbodyTarget, {
      animation: 150,
      handle: ".cursor-move",
      ghostClass: "bg-blue-50",
      dragClass: "opacity-50",
      forceFallback: true,

      // Accessibility: Allow keyboard navigation
      fallbackOnBody: true,
      swapThreshold: 0.65,

      onEnd: (event) => {
        this.handleReorder(event)
      },

      onChoose: (event) => {
        event.item.setAttribute("aria-grabbed", "true")
      },

      onUnchoose: (event) => {
        event.item.setAttribute("aria-grabbed", "false")
      }
    })

    this.addKeyboardSupport()
  }

  addKeyboardSupport() {
    const rows = this.tbodyTarget.querySelectorAll("tr")

    rows.forEach((row, index) => {
      const handle = row.querySelector(".cursor-move")
      if (!handle) return

      handle.setAttribute("tabindex", "0")
      handle.setAttribute("role", "button")
      handle.setAttribute("aria-label", `Reorder variant. Press Space or Enter to grab, Arrow keys to move, Space or Enter to drop.`)

      let grabbed = false

      handle.addEventListener("keydown", (event) => {
        if (event.key === " " || event.key === "Enter") {
          event.preventDefault()
          grabbed = !grabbed

          if (grabbed) {
            row.classList.add("bg-blue-50")
            handle.setAttribute("aria-grabbed", "true")
          } else {
            row.classList.remove("bg-blue-50")
            handle.setAttribute("aria-grabbed", "false")
          }
        } else if (grabbed && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
          event.preventDefault()
          this.moveRow(row, event.key === "ArrowUp" ? -1 : 1)
        } else if (event.key === "Escape" && grabbed) {
          grabbed = false
          row.classList.remove("bg-blue-50")
          handle.setAttribute("aria-grabbed", "false")
        }
      })
    })
  }

  moveRow(row, direction) {
    const rows = Array.from(this.tbodyTarget.querySelectorAll("tr"))
    const currentIndex = rows.indexOf(row)
    const newIndex = currentIndex + direction

    if (newIndex < 0 || newIndex >= rows.length) return

    if (direction === -1) {
      row.previousElementSibling.before(row)
    } else {
      row.nextElementSibling.after(row)
    }

    this.saveOrder()

    // Announce to screen readers
    this.announcePosition(newIndex + 1, rows.length)
  }

  async handleReorder(event) {
    await this.saveOrder()
  }

  async saveOrder() {
    const rows = this.tbodyTarget.querySelectorAll("tr[data-variant-id]")
    const order = Array.from(rows).map(row => row.dataset.variantId)

    const productId = this.extractProductIdFromUrl()
    if (!productId) {
      console.error("Could not determine product ID for reorder")
      return
    }

    try {
      const response = await fetch(`/products/${productId}/variants/reorder`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ order: order })
      })

      if (!response.ok) {
        console.error("Reorder failed:", response.statusText)
        this.showError("Failed to save variant order")
      }
    } catch (error) {
      console.error("Reorder error:", error)
      this.showError("Network error while saving order")
    }
  }

  extractProductIdFromUrl() {
    const match = window.location.pathname.match(/\/products\/(\d+)/)
    return match ? match[1] : null
  }

  announcePosition(position, total) {
    let liveRegion = document.getElementById("variant-reorder-announcer")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "variant-reorder-announcer"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.className = "sr-only"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = `Variant moved to position ${position} of ${total}`
  }

  showError(message) {
    console.error(message)
  }

  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
}
