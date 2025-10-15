import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inventory-table"
export default class extends Controller {
  connect() {
    console.log("Inventory table controller connected")
  }

  // Future: Add inline editing functionality for ETA quantity and date
  editQuantity(event) {
    console.log("Edit quantity clicked", event.currentTarget)
    // TODO: Implement inline editing with Turbo Frames
  }

  editDate(event) {
    console.log("Edit date clicked", event.currentTarget)
    // TODO: Implement inline editing with Turbo Frames
  }

  adjustInventory(event) {
    const button = event.currentTarget
    const sku = button.dataset.sku
    console.log(`Adjust inventory for ${sku}`)
    // TODO: Open modal or navigate to adjustment page
  }
}
