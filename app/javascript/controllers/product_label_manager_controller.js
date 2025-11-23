import { Controller } from "@hotwired/stimulus"

// Product Label Manager Controller
// Handles label search filtering and add/remove on product show page
export default class extends Controller {
  static targets = ["searchInput", "labelList", "labelOption", "emptyState", "selectedContainer", "emptyMessage"]
  static values = {
    productId: Number
  }

  connect() {
    console.log("Product label manager controller connected for product", this.productIdValue)
  }

  // Add a label to the product
  async addLabel(event) {
    const button = event.currentTarget
    const labelId = button.dataset.labelId
    const labelName = button.dataset.labelName
    const labelCode = button.dataset.labelCode || ''
    const labelColor = button.dataset.labelColor
    const productId = this.productIdValue

    console.log('Adding label:', { labelId, labelName, labelCode, labelColor, productId })

    if (!productId) {
      console.error('Product ID is missing!')
      alert('Error: Product ID not found. Please refresh the page.')
      return
    }

    // Optimistically update UI
    this.addLabelToSelected(labelId, labelName, labelCode, labelColor)
    button.remove() // Remove from available list

    // Check if we should show empty message
    this.updateEmptyMessages()

    // Send request to backend
    try {
      const response = await fetch(`/products/${productId}/add_label`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ label_id: labelId })
      })

      if (!response.ok) {
        throw new Error('Failed to add label')
      }

      console.log('Label added successfully')
    } catch (error) {
      console.error('Error adding label:', error)
      // Optionally revert UI on error
      alert('Failed to add label. Please refresh and try again.')
    }
  }

  // Remove a label from the product
  async removeLabel(event) {
    event.preventDefault()
    const button = event.currentTarget
    const labelId = button.dataset.labelId
    // Find the parent span (not the button itself which also has data-label-id)
    const labelTag = button.closest('span[data-label-id][role="listitem"]')

    if (!labelTag) {
      console.error('Label tag not found')
      return
    }

    const labelName = labelTag.dataset.labelName || 'Unknown'
    const labelCode = labelTag.dataset.labelCode || ''
    const labelColor = labelTag.dataset.labelColor || '#6b7280'
    const productId = this.productIdValue

    console.log('Removing label:', { labelId, labelName, labelCode, labelColor, productId, hasProductId: !!productId })

    if (!productId) {
      console.error('Product ID is missing!')
      alert('Error: Product ID not found. Please refresh the page.')
      return
    }

    // Optimistically update UI
    labelTag.remove()
    this.addLabelToAvailable(labelId, labelName, labelCode, labelColor)

    // Check if we should show empty message
    this.updateEmptyMessages()

    // Send request to backend
    try {
      const url = `/products/${productId}/remove_label?label_id=${labelId}`
      console.log('DELETE request to:', url)

      const response = await fetch(url, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        }
      })

      console.log('Response status:', response.status)

      if (!response.ok) {
        const errorText = await response.text()
        console.error('Server error:', errorText)
        throw new Error('Failed to remove label')
      }

      console.log('Label removed successfully')
    } catch (error) {
      console.error('Error removing label:', error)
      // Revert UI on error
      this.addLabelToSelected(labelId, labelName, labelCode, labelColor)

      // Find and remove the button we just added back to available
      const addedButton = this.labelListTarget.querySelector(`[data-label-id="${labelId}"]`)
      if (addedButton) {
        addedButton.remove()
      }

      this.updateEmptyMessages()
      alert('Failed to remove label. Please try again.')
    }
  }

  // Filter labels based on search input
  filterLabels() {
    const query = this.searchInputTarget.value.toLowerCase().trim()
    let hasVisibleLabels = false

    this.labelOptionTargets.forEach(option => {
      const labelName = option.dataset.labelName?.toLowerCase() || ''
      const labelCode = option.dataset.labelCode?.toLowerCase() || ''
      const matches = labelName.includes(query) || labelCode.includes(query)

      if (matches) {
        option.classList.remove('hidden')
        hasVisibleLabels = true
      } else {
        option.classList.add('hidden')
      }
    })

    // Toggle empty state
    if (query && !hasVisibleLabels) {
      this.labelListTarget.classList.add('hidden')
      this.emptyStateTarget.classList.remove('hidden')
    } else {
      this.labelListTarget.classList.remove('hidden')
      this.emptyStateTarget.classList.add('hidden')
    }
  }

  // Helper: Add label to selected container
  addLabelToSelected(labelId, labelName, labelCode, labelColor) {
    // Remove empty message if exists
    const emptyMessage = this.selectedContainerTarget.querySelector('[data-product-label-manager-target="emptyMessage"]')
    if (emptyMessage) {
      emptyMessage.remove()
    }

    // Sanitize color to prevent CSS injection
    const safeColor = this.sanitizeColor(labelColor)

    // Create elements safely using DOM API to prevent XSS
    const labelSpan = document.createElement('span')
    labelSpan.className = 'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm bg-blue-100 text-blue-800 border border-blue-200'
    labelSpan.setAttribute('data-label-id', labelId)
    labelSpan.setAttribute('data-label-name', labelName)
    labelSpan.setAttribute('data-label-code', labelCode || '')
    labelSpan.setAttribute('data-label-color', safeColor)
    labelSpan.setAttribute('role', 'listitem')

    const colorDot = document.createElement('span')
    colorDot.className = 'h-2 w-2 rounded-full flex-shrink-0'
    colorDot.style.backgroundColor = safeColor
    colorDot.setAttribute('aria-hidden', 'true')

    const nameSpan = document.createElement('span')
    nameSpan.className = 'font-medium'
    nameSpan.textContent = labelName

    const removeButton = document.createElement('button')
    removeButton.type = 'button'
    removeButton.className = 'ml-1 inline-flex items-center justify-center h-4 w-4 rounded-full hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 transition-colors'
    removeButton.setAttribute('data-action', 'click->product-label-manager#removeLabel')
    removeButton.setAttribute('data-label-id', labelId)
    removeButton.setAttribute('aria-label', `Remove label ${labelName}`)

    const srOnly = document.createElement('span')
    srOnly.className = 'sr-only'
    srOnly.textContent = `Remove label ${labelName}`

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.setAttribute('class', 'h-3 w-3')
    svg.setAttribute('viewBox', '0 0 20 20')
    svg.setAttribute('fill', 'currentColor')
    svg.setAttribute('aria-hidden', 'true')

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('d', 'M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z')

    svg.appendChild(path)
    removeButton.appendChild(srOnly)
    removeButton.appendChild(svg)

    labelSpan.appendChild(colorDot)
    labelSpan.appendChild(nameSpan)
    labelSpan.appendChild(removeButton)

    this.selectedContainerTarget.appendChild(labelSpan)
  }

  // Helper: Add label back to available list
  addLabelToAvailable(labelId, labelName, labelCode, labelColor) {
    // Sanitize color to prevent CSS injection
    const safeColor = this.sanitizeColor(labelColor)

    // Create elements safely using DOM API to prevent XSS
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'w-full text-left px-3 py-2 rounded-md text-sm hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-blue-50 transition-colors'
    button.setAttribute('data-label-id', labelId)
    button.setAttribute('data-label-name', labelName)
    button.setAttribute('data-label-code', labelCode || '')
    button.setAttribute('data-label-color', safeColor)
    button.setAttribute('data-action', 'click->product-label-manager#addLabel')
    button.setAttribute('data-product-label-manager-target', 'labelOption')
    button.setAttribute('aria-label', `Add label ${labelName}`)

    const div = document.createElement('div')
    div.className = 'flex items-center gap-2'

    const colorDot = document.createElement('span')
    colorDot.className = 'h-2 w-2 rounded-full flex-shrink-0'
    colorDot.style.backgroundColor = safeColor
    colorDot.setAttribute('aria-hidden', 'true')

    const nameSpan = document.createElement('span')
    nameSpan.className = 'text-gray-900'
    nameSpan.textContent = labelName

    div.appendChild(colorDot)
    div.appendChild(nameSpan)
    button.appendChild(div)

    // Find the container inside labelList
    const container = this.labelListTarget.querySelector('.space-y-1')
    if (container) {
      container.appendChild(button)
    }
  }

  // Helper: Update empty messages
  updateEmptyMessages() {
    // Check selected labels
    const selectedLabels = this.selectedContainerTarget.querySelectorAll('[data-label-id]')
    if (selectedLabels.length === 0) {
      const emptyMessage = `<p class="text-sm text-gray-500 py-1" data-product-label-manager-target="emptyMessage">No labels selected. Click on labels above to add them.</p>`
      this.selectedContainerTarget.innerHTML = emptyMessage
    }

    // Check available labels
    const availableLabels = this.labelListTarget.querySelectorAll('[data-product-label-manager-target="labelOption"]')
    const container = this.labelListTarget.querySelector('.space-y-1')
    if (availableLabels.length === 0 && container) {
      container.innerHTML = '<p class="text-sm text-gray-500 text-center py-4">No labels available. All labels are already assigned or create new labels first.</p>'
    }
  }

  // Get CSRF token for requests
  // Sanitize hex color to prevent CSS injection
  // Only allows valid hex colors (#RGB or #RRGGBB)
  sanitizeColor(color) {
    const hexColorPattern = /^#(?:[0-9a-fA-F]{3}){1,2}$/
    if (!color || !hexColorPattern.test(color)) {
      return '#6b7280' // Default gray color if invalid
    }
    return color
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
