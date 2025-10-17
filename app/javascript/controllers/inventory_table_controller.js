import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inventory-table"
export default class extends Controller {
  connect() {
    console.log("Inventory table controller connected")
  }

  // Opens the adjust inventory modal with product data
  openAdjustModal(event) {
    const button = event.currentTarget
    const productId = button.dataset.productId
    const productSku = button.dataset.productSku
    const productName = button.dataset.productName
    const inventoryId = button.dataset.inventoryId
    const currentValue = parseInt(button.dataset.currentValue) || 0
    const etaQuantity = parseInt(button.dataset.etaQuantity) || 0
    const etaDate = button.dataset.etaDate || ''

    console.log('Opening modal with data:', {
      productId, productSku, productName, inventoryId,
      currentValue, etaQuantity, etaDate
    })

    // Update modal content with product info
    document.getElementById('modal-product-name').textContent = `Adjust Inventory - ${productSku}`
    document.getElementById('modal-product-sku').textContent = productSku
    document.getElementById('modal-product-description').textContent = productName

    // Update form action URL
    const form = document.getElementById('adjust-inventory-form')
    form.action = `/products/${productId}/inventories/${inventoryId}`

    // Reset form first
    form.reset()

    // Populate form fields with current values
    const valueInput = document.getElementById('inventory-value')
    const etaQuantityInput = document.getElementById('eta-quantity')
    const etaDateInput = document.getElementById('eta-date')

    if (valueInput) {
      valueInput.value = currentValue
      // Update placeholder to show current value
      valueInput.placeholder = `Current: ${currentValue}`
    }

    if (etaQuantityInput) {
      etaQuantityInput.value = etaQuantity
      // Update placeholder to show current value
      etaQuantityInput.placeholder = `Current: ${etaQuantity}`
    }

    if (etaDateInput && etaDate) {
      etaDateInput.value = etaDate
    }

    // Trigger the inventory form controller to update total available
    const inventoryFormController = this.application.getControllerForElementAndIdentifier(
      form.closest('[data-controller="inventory-form"]'),
      "inventory-form"
    )
    if (inventoryFormController) {
      inventoryFormController.updateTotalAvailable()
    }

    // Trigger modal open event
    const modalWrapper = document.getElementById('adjust-inventory-modal-wrapper')
    if (modalWrapper) {
      const modalController = this.application.getControllerForElementAndIdentifier(modalWrapper, "modal")
      if (modalController) {
        modalController.open()
      }
    }
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
}
