import { Controller } from "@hotwired/stimulus"

/**
 * Bundle Composer Controller
 *
 * Manages the bundle product composition interface, including:
 * - Product search and selection
 * - Sellable and configurable product management
 * - Variant selection and quantity management
 * - Real-time preview of bundle combinations
 * - Configuration validation and limits
 *
 * Targets:
 *   - composer: Main composer container
 *   - searchInput: Product search input field
 *   - searchResults: Search results dropdown
 *   - selectedProducts: Container for selected product cards
 *   - preview: Preview section
 *   - previewCount: Combination count display
 *   - configuration: Hidden input for form submission
 *   - productCount: Selected products count display
 *   - errorContainer: Error messages container
 *   - warningContainer: Warning messages container
 *   - submitButton: Form submit button
 *
 * Values:
 *   - maxConfigurables: Maximum configurable products allowed (default: 3)
 *   - maxSellables: Maximum sellable products allowed (default: 10)
 *   - maxCombinations: Maximum variant combinations allowed (default: 200)
 *
 * Actions:
 *   - productTypeChanged: Show/hide composer based on product type
 *   - search: Search for products
 *   - addProduct: Add product to bundle
 *   - removeProduct: Remove product from bundle
 *   - toggleVariant: Toggle variant inclusion
 *   - quantityChanged: Update quantity
 *
 * Usage:
 *   <div data-controller="bundle-composer"
 *        data-bundle-composer-max-configurables-value="3"
 *        data-bundle-composer-max-sellables-value="10"
 *        data-bundle-composer-max-combinations-value="200">
 *     ...composer UI...
 *   </div>
 *
 * Accessibility:
 * - Keyboard navigation support
 * - ARIA labels and announcements
 * - Focus management
 * - Screen reader-friendly error messages
 */
export default class extends Controller {
  static targets = [
    "composer",
    "searchInput",
    "searchResults",
    "selectedProducts",
    "preview",
    "previewCount",
    "configuration",
    "productCount",
    "errorContainer",
    "warningContainer",
    "submitButton"
  ]

  static values = {
    maxConfigurables: { type: Number, default: 3 },
    maxSellables: { type: Number, default: 10 },
    maxCombinations: { type: Number, default: 200 }
  }

  /**
   * Initialize controller state
   */
  connect() {
    console.log("Bundle Composer connected")

    // Track selected products: Map(productId => { type, name, data })
    this.selectedProducts = new Map()

    // Debounce timers
    this.searchDebounce = null
    this.previewDebounce = null

    // Check if we have existing configuration to restore
    this.restoreExistingConfiguration()
  }

  /**
   * Clean up when controller disconnects
   */
  disconnect() {
    if (this.searchDebounce) clearTimeout(this.searchDebounce)
    if (this.previewDebounce) clearTimeout(this.previewDebounce)
  }

  /**
   * Show/hide composer based on product type selection
   *
   * @param {Event} event - Change event from product type select
   */
  productTypeChanged(event) {
    const productType = event.target.value
    const isBundle = productType === "3" || productType === "bundle"

    if (this.hasComposerTarget) {
      if (isBundle) {
        this.composerTarget.classList.remove("hidden")
      } else {
        this.composerTarget.classList.add("hidden")
      }
    }

    // Reset composer if switching away from bundle
    if (!isBundle) {
      this.resetComposer()
    }
  }

  /**
   * Search for products (debounced)
   *
   * @param {Event} event - Input event from search field
   */
  search(event) {
    const query = event.target.value.trim()

    // Clear previous debounce
    if (this.searchDebounce) {
      clearTimeout(this.searchDebounce)
    }

    // Hide results if query too short
    if (query.length < 2) {
      this.hideSearchResults()
      return
    }

    // Debounce search to avoid excessive requests (300ms)
    this.searchDebounce = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  /**
   * Perform the actual search request
   *
   * @param {String} query - Search query
   */
  async performSearch(query) {
    try {
      const response = await fetch(`/bundle_composer/search?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error("Search failed")
      }

      const data = await response.json()
      this.displaySearchResults(data.products || [])
    } catch (error) {
      console.error("Search error:", error)
      this.showError("Failed to search products")
    }
  }

  /**
   * Display search results
   *
   * @param {Array} products - Array of product objects
   */
  displaySearchResults(products) {
    if (!this.hasSearchResultsTarget) return

    if (products.length === 0) {
      this.searchResultsTarget.innerHTML = `
        <div class="p-4 text-sm text-gray-500">
          No products found
        </div>
      `
    } else {
      this.searchResultsTarget.innerHTML = products.map(product => {
        const isDisabled = this.selectedProducts.has(product.id.toString())
        const disabledClass = isDisabled ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50 cursor-pointer'
        const badge = product.product_type === 'configurable'
          ? '<span class="px-2 py-1 text-xs font-medium text-blue-600 bg-blue-100 rounded">Configurable</span>'
          : '<span class="px-2 py-1 text-xs font-medium text-green-600 bg-green-100 rounded">Sellable</span>'

        return `
          <div class="p-3 border-b border-gray-200 ${disabledClass}"
               data-action="click->bundle-composer#addProduct"
               data-product-id="${product.id}"
               data-product-type="${product.product_type}"
               data-product-name="${product.name}"
               data-product-sku="${product.sku}">
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <div class="font-medium text-sm text-gray-900">${product.name}</div>
                <div class="text-xs text-gray-500">${product.sku}</div>
              </div>
              ${badge}
            </div>
            ${isDisabled ? '<div class="text-xs text-gray-500 mt-1">Already added</div>' : ''}
          </div>
        `
      }).join('')
    }

    this.searchResultsTarget.style.display = 'block'
  }

  /**
   * Hide search results dropdown
   */
  hideSearchResults() {
    if (this.hasSearchResultsTarget) {
      this.searchResultsTarget.style.display = 'none'
    }
  }

  /**
   * Add product to bundle composition
   *
   * @param {Event} event - Click event from search result
   */
  async addProduct(event) {
    const productId = event.currentTarget.dataset.productId
    const productType = event.currentTarget.dataset.productType
    const productName = event.currentTarget.dataset.productName
    const productSku = event.currentTarget.dataset.productSku

    // Check if already added
    if (this.selectedProducts.has(productId)) {
      this.showWarning("Product already added to bundle")
      return
    }

    // Check limits before adding
    if (!this.canAddProduct(productType)) {
      return // Error already shown by canAddProduct
    }

    // Fetch full product details including variants
    try {
      const response = await fetch(`/bundle_composer/product/${productId}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error("Failed to fetch product details")
      }

      const productData = await response.json()

      // Add to selected products
      this.selectedProducts.set(productId, {
        type: productType,
        name: productName,
        sku: productSku,
        data: productData
      })

      // Render product card
      this.renderProductCard(productId, productType, productName, productSku, productData)

      // Update counts and preview
      this.updateProductCount()
      this.updatePreview()

      // Clear search
      if (this.hasSearchInputTarget) {
        this.searchInputTarget.value = ''
      }
      this.hideSearchResults()

      // Announce to screen readers
      this.announce(`Added ${productName} to bundle`)

    } catch (error) {
      console.error("Add product error:", error)
      this.showError("Failed to add product")
    }
  }

  /**
   * Check if product can be added (respecting limits)
   *
   * @param {String} productType - 'sellable' or 'configurable'
   * @returns {Boolean} Whether product can be added
   */
  canAddProduct(productType) {
    const configurableCount = Array.from(this.selectedProducts.values())
      .filter(p => p.type === 'configurable').length
    const sellableCount = Array.from(this.selectedProducts.values())
      .filter(p => p.type === 'sellable').length

    if (productType === 'configurable' && configurableCount >= this.maxConfigurablesValue) {
      this.showError(`Maximum ${this.maxConfigurablesValue} configurable products allowed`)
      return false
    }

    if (productType === 'sellable' && sellableCount >= this.maxSellablesValue) {
      this.showError(`Maximum ${this.maxSellablesValue} sellable products allowed`)
      return false
    }

    return true
  }

  /**
   * Render product card in selected products area
   *
   * @param {String} productId - Product ID
   * @param {String} productType - Product type
   * @param {String} productName - Product name
   * @param {String} productSku - Product SKU
   * @param {Object} productData - Full product data
   */
  renderProductCard(productId, productType, productName, productSku, productData) {
    if (!this.hasSelectedProductsTarget) return

    const card = document.createElement('div')
    card.className = 'bg-white border border-gray-200 rounded-lg p-4 mb-3'
    card.dataset.productCard = ''
    card.dataset.productId = productId
    card.dataset.productType = productType

    if (productType === 'configurable') {
      card.innerHTML = this.renderConfigurableCard(productId, productName, productSku, productData)
    } else {
      card.innerHTML = this.renderSellableCard(productId, productName, productSku)
    }

    this.selectedProductsTarget.appendChild(card)
  }

  /**
   * Render sellable product card HTML
   *
   * @param {String} productId - Product ID
   * @param {String} productName - Product name
   * @param {String} productSku - Product SKU
   * @returns {String} HTML string
   */
  renderSellableCard(productId, productName, productSku) {
    return `
      <div class="flex items-start justify-between mb-3">
        <div>
          <h4 class="font-medium text-gray-900">${productName}</h4>
          <p class="text-sm text-gray-500">${productSku}</p>
          <span class="inline-block px-2 py-1 text-xs font-medium text-green-600 bg-green-100 rounded mt-1">
            Sellable
          </span>
        </div>
        <button type="button"
                data-action="click->bundle-composer#removeProduct"
                data-product-id="${productId}"
                class="text-gray-400 hover:text-red-600"
                aria-label="Remove product">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="mt-3">
        <label class="block text-sm font-medium text-gray-700 mb-1">
          Quantity
        </label>
        <input type="number"
               min="1"
               value="1"
               data-quantity-input
               data-action="input->bundle-composer#quantityChanged"
               class="w-24 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" />
      </div>
    `
  }

  /**
   * Render configurable product card HTML
   *
   * @param {String} productId - Product ID
   * @param {String} productName - Product name
   * @param {String} productSku - Product SKU
   * @param {Object} productData - Full product data with variants
   * @returns {String} HTML string
   */
  renderConfigurableCard(productId, productName, productSku, productData) {
    const variants = productData.variants || []
    const variantRows = variants.map(variant => `
      <tr data-variant-row data-variant-id="${variant.id}" data-variant-code="${variant.variant_code || ''}">
        <td class="px-3 py-2">
          <input type="checkbox"
                 checked
                 data-variant-checkbox
                 data-action="change->bundle-composer#toggleVariant"
                 class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
        </td>
        <td class="px-3 py-2 text-sm text-gray-900">${variant.sku}</td>
        <td class="px-3 py-2 text-sm text-gray-500">${variant.name || '-'}</td>
        <td class="px-3 py-2 text-sm text-gray-500">${variant.variant_code || '-'}</td>
        <td class="px-3 py-2">
          <input type="number"
                 min="1"
                 value="1"
                 data-variant-quantity
                 data-action="input->bundle-composer#quantityChanged"
                 class="w-20 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" />
        </td>
      </tr>
    `).join('')

    return `
      <div class="flex items-start justify-between mb-3">
        <div>
          <h4 class="font-medium text-gray-900">${productName}</h4>
          <p class="text-sm text-gray-500">${productSku}</p>
          <span class="inline-block px-2 py-1 text-xs font-medium text-blue-600 bg-blue-100 rounded mt-1">
            Configurable
          </span>
        </div>
        <button type="button"
                data-action="click->bundle-composer#removeProduct"
                data-product-id="${productId}"
                class="text-gray-400 hover:text-red-600"
                aria-label="Remove product">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="mt-4">
        <h5 class="text-sm font-medium text-gray-700 mb-2">
          Variants (${variants.length})
        </h5>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Include</th>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">SKU</th>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Config</th>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Qty</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              ${variantRows}
            </tbody>
          </table>
        </div>
      </div>
    `
  }

  /**
   * Remove product from bundle
   *
   * @param {Event} event - Click event from remove button
   */
  removeProduct(event) {
    const productId = event.currentTarget.dataset.productId
    const product = this.selectedProducts.get(productId)

    if (!product) return

    // Remove from map
    this.selectedProducts.delete(productId)

    // Remove card from DOM
    const card = this.selectedProductsTarget.querySelector(`[data-product-card][data-product-id="${productId}"]`)
    if (card) {
      card.remove()
    }

    // Update counts and preview
    this.updateProductCount()
    this.updatePreview()

    // Announce to screen readers
    this.announce(`Removed ${product.name} from bundle`)
  }

  /**
   * Toggle variant inclusion
   *
   * @param {Event} event - Change event from variant checkbox
   */
  toggleVariant(event) {
    // Update preview when variant selection changes
    this.updatePreview()
  }

  /**
   * Handle quantity changes
   *
   * @param {Event} event - Input event from quantity field
   */
  quantityChanged(event) {
    // Update preview when quantities change
    this.updatePreview()
  }

  /**
   * Build configuration object from current DOM state
   *
   * @returns {Object} Configuration object
   */
  buildConfiguration() {
    const components = []

    // Iterate through all product cards
    const cards = this.selectedProductsTarget.querySelectorAll('[data-product-card]')

    cards.forEach(card => {
      const productId = card.dataset.productId
      const productType = card.dataset.productType
      const product = this.selectedProducts.get(productId)

      if (!product) return

      if (productType === 'sellable') {
        const quantityInput = card.querySelector('[data-quantity-input]')
        const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1

        components.push({
          product_id: parseInt(productId),
          product_type: 'sellable',
          quantity: quantity
        })
      } else if (productType === 'configurable') {
        // Collect all variants for this configurable product
        const variants = []
        const variantRows = card.querySelectorAll('[data-variant-row]')

        variantRows.forEach(row => {
          const checkbox = row.querySelector('[data-variant-checkbox]')
          const quantityInput = row.querySelector('[data-variant-quantity]')
          const variantId = row.dataset.variantId
          const isIncluded = checkbox ? checkbox.checked : false
          const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1

          variants.push({
            variant_id: parseInt(variantId),
            included: isIncluded,
            quantity: quantity
          })
        })

        // Add single component for configurable product with all variants
        components.push({
          product_id: parseInt(productId),
          product_type: 'configurable',
          variants: variants
        })
      }
    })

    return { components }
  }

  /**
   * Update preview (debounced)
   */
  updatePreview() {
    // Clear previous debounce
    if (this.previewDebounce) {
      clearTimeout(this.previewDebounce)
    }

    // Clear errors/warnings
    this.clearMessages()

    // Debounce preview update to avoid excessive requests (500ms)
    this.previewDebounce = setTimeout(() => {
      this.performPreviewUpdate()
    }, 500)
  }

  /**
   * Perform the actual preview update
   */
  async performPreviewUpdate() {
    const configuration = this.buildConfiguration()

    // Update hidden field
    if (this.hasConfigurationTarget) {
      this.configurationTarget.value = JSON.stringify(configuration)
    }

    // If no components, clear preview
    if (configuration.components.length === 0) {
      this.clearPreview()
      this.disableSubmit("Add at least one product to the bundle")
      return
    }

    // Request preview from server
    try {
      const response = await fetch('/bundle_composer/preview', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ configuration })
      })

      if (!response.ok) {
        throw new Error("Preview failed")
      }

      const data = await response.json()
      this.displayPreview(data)

    } catch (error) {
      console.error("Preview error:", error)
      this.showError("Failed to generate preview")
      this.disableSubmit("Preview generation failed")
    }
  }

  /**
   * Display preview data
   *
   * @param {Object} data - Preview data from server
   */
  displayPreview(data) {
    if (!this.hasPreviewTarget) return

    // Check for errors
    if (data.errors && data.errors.length > 0) {
      data.errors.forEach(error => this.showError(error))
      this.disableSubmit("Fix errors before saving")
      return
    }

    // Check for warnings
    if (data.warnings && data.warnings.length > 0) {
      data.warnings.forEach(warning => this.showWarning(warning))
    }

    // Update combination count
    if (this.hasPreviewCountTarget) {
      const count = data.combination_count || 0
      this.previewCountTarget.textContent = count

      // Warn if approaching limit
      if (count > this.maxCombinationsValue * 0.8) {
        this.showWarning(`Approaching combination limit (${count}/${this.maxCombinationsValue})`)
      }
    }

    // Check if valid
    if (data.valid) {
      this.enableSubmit()
    } else {
      this.disableSubmit(data.message || "Configuration is invalid")
    }
  }

  /**
   * Clear preview display
   */
  clearPreview() {
    if (this.hasPreviewCountTarget) {
      this.previewCountTarget.textContent = '0'
    }
  }

  /**
   * Update selected products count display
   */
  updateProductCount() {
    if (this.hasProductCountTarget) {
      this.productCountTarget.textContent = this.selectedProducts.size
    }
  }

  /**
   * Enable form submission
   */
  enableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  /**
   * Disable form submission with reason
   *
   * @param {String} reason - Reason for disabling
   */
  disableSubmit(reason) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
      this.submitButtonTarget.title = reason
    }
  }

  /**
   * Show error message
   *
   * @param {String} message - Error message
   */
  showError(message) {
    if (!this.hasErrorContainerTarget) return

    const alert = this.createAlert(message, 'error')
    this.errorContainerTarget.appendChild(alert)
    this.errorContainerTarget.style.display = 'block'
  }

  /**
   * Show warning message
   *
   * @param {String} message - Warning message
   */
  showWarning(message) {
    if (!this.hasWarningContainerTarget) return

    const alert = this.createAlert(message, 'warning')
    this.warningContainerTarget.appendChild(alert)
    this.warningContainerTarget.style.display = 'block'
  }

  /**
   * Create alert element
   *
   * @param {String} message - Alert message
   * @param {String} type - 'error' or 'warning'
   * @returns {HTMLElement} Alert element
   */
  createAlert(message, type) {
    const alert = document.createElement('div')
    const bgColor = type === 'error' ? 'bg-red-50 border-red-200' : 'bg-yellow-50 border-yellow-200'
    const textColor = type === 'error' ? 'text-red-800' : 'text-yellow-800'

    alert.className = `${bgColor} border ${textColor} px-4 py-3 rounded mb-2 flex items-center justify-between`
    alert.innerHTML = `
      <span class="text-sm">${message}</span>
      <button type="button"
              data-action="click->bundle-composer#dismissAlert"
              class="text-current opacity-50 hover:opacity-100">
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    `

    return alert
  }

  /**
   * Dismiss individual alert
   *
   * @param {Event} event - Click event from dismiss button
   */
  dismissAlert(event) {
    const alert = event.currentTarget.closest('div')
    if (alert) {
      alert.remove()
    }

    // Hide containers if empty
    if (this.hasErrorContainerTarget && this.errorContainerTarget.children.length === 0) {
      this.errorContainerTarget.style.display = 'none'
    }
    if (this.hasWarningContainerTarget && this.warningContainerTarget.children.length === 0) {
      this.warningContainerTarget.style.display = 'none'
    }
  }

  /**
   * Clear all error and warning messages
   */
  clearMessages() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = ''
      this.errorContainerTarget.style.display = 'none'
    }
    if (this.hasWarningContainerTarget) {
      this.warningContainerTarget.innerHTML = ''
      this.warningContainerTarget.style.display = 'none'
    }
  }

  /**
   * Reset composer to initial state
   */
  resetComposer() {
    this.selectedProducts.clear()

    if (this.hasSelectedProductsTarget) {
      this.selectedProductsTarget.innerHTML = ''
    }

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }

    this.hideSearchResults()
    this.clearMessages()
    this.clearPreview()
    this.updateProductCount()

    if (this.hasConfigurationTarget) {
      this.configurationTarget.value = ''
    }
  }

  /**
   * Restore existing configuration (for edit mode)
   */
  restoreExistingConfiguration() {
    if (!this.hasConfigurationTarget) return

    const configJson = this.configurationTarget.value
    if (!configJson) return

    try {
      const configuration = JSON.parse(configJson)

      // TODO: Implement restoration logic if needed for edit mode
      // This would fetch product details and rebuild the UI

    } catch (error) {
      console.error("Failed to restore configuration:", error)
    }
  }

  /**
   * Announce message to screen readers
   *
   * @param {String} message - Message to announce
   */
  announce(message) {
    let liveRegion = document.getElementById("bundle-composer-announcer")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "bundle-composer-announcer"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.className = "sr-only"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = message
  }

  /**
   * Get CSRF token from meta tag
   *
   * @returns {String} CSRF token
   */
  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
}
