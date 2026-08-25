import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoOpenProduct: String }

  connect() {
    if (this.hasAutoOpenProductValue && this.autoOpenProductValue) {
      setTimeout(() => this.autoOpenForProduct(this.autoOpenProductValue), 100)
    }
  }

  autoOpenForProduct(productId) {
    const button = this.element.querySelector(`button[data-action*="openAdjustModal"][data-inventory-id]`)
    const rows = this.element.querySelectorAll(`tr[data-product-id="${productId}"]`)
    if (rows.length > 0) {
      const parentRow = rows[0].closest('table')?.querySelector(`tr[data-controller="expandable-row"]`)
      if (parentRow) {
        const expandController = this.application.getControllerForElementAndIdentifier(parentRow, "expandable-row")
        if (expandController) expandController.expand()
      }

      const adjustBtn = rows[0].querySelector('button[data-action*="openAdjustModal"]')
      if (adjustBtn) {
        rows[0].scrollIntoView({ behavior: 'smooth', block: 'center' })
        adjustBtn.click()
      }
    }
  }

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

    document.getElementById('modal-product-name').textContent = `Adjust Inventory - ${productSku}`
    document.getElementById('modal-product-sku').textContent = productSku
    document.getElementById('modal-product-description').textContent = productName

    const storageNameEl = document.getElementById('modal-storage-name')
    const storageCodeEl = document.getElementById('modal-storage-code')
    if (storageNameEl && storageName) {
      storageNameEl.textContent = storageName
    }
    if (storageCodeEl && storageCode) {
      storageCodeEl.textContent = storageCode
    }

    const form = document.getElementById('adjust-inventory-form')
    const updateUrl = button.dataset.updateUrl
    form.action = updateUrl || `/products/${productId}/inventories/${inventoryId}`

    form.reset()

    const valueInput = document.getElementById('inventory-value')
    const etaQuantityInput = document.getElementById('eta-quantity')
    const etaDateInput = document.getElementById('eta-date')

    if (valueInput) {
      valueInput.value = currentValue
      valueInput.placeholder = `Current: ${currentValue}`
    }

    if (etaQuantityInput) {
      etaQuantityInput.value = etaQuantity
      etaQuantityInput.placeholder = `Current: ${etaQuantity}`
    }

    if (etaDateInput && etaDate) {
      etaDateInput.value = etaDate
    }

    const inventoryFormController = this.application.getControllerForElementAndIdentifier(
      form.closest('[data-controller="inventory-form"]'),
      "inventory-form"
    )
    if (inventoryFormController) {
      inventoryFormController.updateTotalAvailable()
    }

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

  editQuantity(event) {
    console.log("Edit quantity clicked", event.currentTarget)
    // TODO: Implement inline editing with Turbo Frames
  }

  editDate(event) {
    console.log("Edit date clicked", event.currentTarget)
    // TODO: Implement inline editing with Turbo Frames
  }
}
