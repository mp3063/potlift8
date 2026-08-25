import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    handle: { type: String, default: "[data-sortable-handle]" },
    animation: { type: Number, default: 150 },
    group: { type: String, default: "" }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: this.animationValue,
      handle: this.hasHandleValue ? this.handleValue : null,
      group: this.groupValue || undefined,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      onEnd: this.handleDrop.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async handleDrop(event) {
    if (!this.hasUrlValue) {
      console.warn("Sortable: No URL value provided, skipping server update")
      return
    }

    const items = this.element.querySelectorAll("[data-sortable-id]")
    const assetIds = Array.from(items).map(item => item.dataset.sortableId)

    this.element.classList.add("opacity-50", "pointer-events-none")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ asset_ids: assetIds })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      if (data.success) {
        this.showNotification("Order saved", "success")
      }
    } catch (error) {
      console.error("Sortable: Failed to save order", error)
      this.showNotification("Failed to save order", "error")

    } finally {
      this.element.classList.remove("opacity-50", "pointer-events-none")
    }
  }

  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.getAttribute("content") : ""
  }

  showNotification(message, type) {
    const flashContainer = document.getElementById("flash")
    if (flashContainer) {
      const colorClass = type === "success" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"

      const notification = document.createElement("div")
      notification.className = `p-4 rounded-md ${colorClass} mb-4 transition-opacity duration-300`
      notification.textContent = message

      flashContainer.appendChild(notification)

      setTimeout(() => {
        notification.classList.add("opacity-0")
        setTimeout(() => notification.remove(), 300)
      }, 3000)
    }
  }
}
