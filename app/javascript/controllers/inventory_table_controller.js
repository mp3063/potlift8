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
    const storageName = button.dataset.storageName
    const storageCode = button.dataset.storageCode
    const currentValue = parseInt(button.dataset.currentValue) || 0
    const etaQuantity = parseInt(button.dataset.etaQuantity) || 0
    const etaDate = button.dataset.etaDate || ''

    console.log('Opening modal with data:', {
      productId, productSku, productName, inventoryId,
      storageName, storageCode, currentValue, etaQuantity, etaDate
    })

    // Update modal content with product info
    document.getElementById('modal-product-name').textContent = `Adjust Inventory - ${productSku}`
    document.getElementById('modal-product-sku').textContent = productSku
    document.getElementById('modal-product-description').textContent = productName

    // Update storage info (if elements exist - for product inventories view)
    const storageNameEl = document.getElementById('modal-storage-name')
    const storageCodeEl = document.getElementById('modal-storage-code')
    if (storageNameEl && storageName) {
      storageNameEl.textContent = storageName
    }
    if (storageCodeEl && storageCode) {
      storageCodeEl.textContent = storageCode
    }

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
    // Use setTimeout to ensure modal controller is fully initialized
    setTimeout(() => {
      const modalElement = document.querySelector('[data-controller="modal"][data-modal-closable-value="true"]')
      console.log('Modal element found:', modalElement)

      if (modalElement) {
        const modalController = this.application.getControllerForElementAndIdentifier(modalElement, "modal")
        console.log('Modal controller:', modalController)

        if (modalController) {
          console.log('Opening modal...')
          modalController.open()
        } else {
          console.error("Modal controller not found on element:", modalElement)
        }
      } else {
        console.error("Modal element not found")
      }
    }, 50)
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
