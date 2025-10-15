import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="catalog-items"
export default class extends Controller {
  static targets = ["items", "item", "handle"]
  static values = {
    catalogId: Number
  }

  connect() {
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeSortable() {
    if (!this.hasItemsTarget) return

    this.sortable = Sortable.create(this.itemsTarget, {
      animation: 150,
      handle: "[data-catalog-items-target='handle']",
      ghostClass: "bg-blue-50",
      dragClass: "opacity-50",
      onEnd: this.handleReorder.bind(this)
    })
  }

  async handleReorder(event) {
    const itemIds = this.itemTargets.map(item => item.dataset.id)

    try {
      const response = await fetch(`/catalogs/${this.catalogIdValue}/reorder_items`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ item_ids: itemIds })
      })

      if (!response.ok) {
        throw new Error("Failed to reorder items")
      }

      // Show success notification (optional)
      this.showNotification("Items reordered successfully", "success")
    } catch (error) {
      console.error("Error reordering items:", error)

      // Revert the visual change
      if (event.oldIndex !== undefined && event.newIndex !== undefined) {
        this.sortable.option("disabled", true)
        const movedItem = this.itemTargets[event.newIndex]
        const targetIndex = event.oldIndex

        if (targetIndex === 0) {
          this.itemsTarget.insertBefore(movedItem, this.itemsTarget.firstChild)
        } else {
          this.itemsTarget.insertBefore(movedItem, this.itemTargets[targetIndex])
        }

        this.sortable.option("disabled", false)
      }

      this.showNotification("Failed to reorder items", "error")
    }
  }

  showNotification(message, type) {
    // Simple notification - could be enhanced with a proper notification system
    const alertClass = type === "success" ? "bg-green-50 text-green-800" : "bg-red-50 text-red-800"
    const notification = document.createElement("div")
    notification.className = `fixed top-20 right-4 z-50 px-4 py-3 rounded-lg shadow-lg ${alertClass} transition-opacity duration-300`
    notification.textContent = message

    document.body.appendChild(notification)

    setTimeout(() => {
      notification.style.opacity = "0"
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
