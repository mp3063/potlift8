import { Controller } from "@hotwired/stimulus"

/**
 * Global search controller with keyboard shortcut support
 *
 * Handles global search with CMD/CTRL+K shortcut:
 * - Opens search modal
 * - Debounced search (300ms)
 * - Multi-scope search (products, storage, attributes, labels, catalogs)
 * - Recent searches display
 * - Loading and error states
 * - Keyboard navigation
 * - Focus management
 *
 * @example
 *   <div data-controller="global-search">
 *     <div data-global-search-target="modal" class="hidden">
 *       <input data-global-search-target="input" data-action="input->global-search#handleInput">
 *       <div data-global-search-target="results"></div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "results", "modal"]

  connect() {
    // Listen for CMD/CTRL+K keyboard shortcut
    this.keyboardHandler = this.handleKeyboardShortcut.bind(this)
    document.addEventListener("keydown", this.keyboardHandler)

    // Click outside handler
    this.outsideClickHandler = this.handleOutsideClick.bind(this)

    this.debounceTimer = null
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyboardHandler)
    document.removeEventListener("click", this.outsideClickHandler)
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  /**
   * Handle keyboard shortcuts
   * - CMD/CTRL+K: Open search modal
   * - Escape: Close modal
   */
  handleKeyboardShortcut(event) {
    // CMD/CTRL+K to open search
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault()
      this.open()
    }

    // Escape to close
    if (event.key === 'Escape' && this.isOpen()) {
      this.close()
    }
  }

  /**
   * Open the search dropdown
   * - Shows dropdown
   * - Focuses input
   * - Loads recent searches
   * - Adds outside click listener
   */
  open() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.inputTarget.focus()

      // Load recent searches if input is empty
      if (!this.inputTarget.value.trim()) {
        this.loadRecentSearches()
      }

      // Add click listener after a short delay
      setTimeout(() => {
        document.addEventListener("click", this.outsideClickHandler)
      }, 100)
    }
  }

  /**
   * Close the search dropdown
   * - Hides dropdown
   * - Clears input and results
   * - Removes outside click listener
   */
  close(event) {
    if (event) event.preventDefault()

    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.inputTarget.value = ""
      this.resultsTarget.innerHTML = ""
      document.removeEventListener("click", this.outsideClickHandler)
    }
  }

  /**
   * Check if modal is currently open
   * @returns {boolean}
   */
  isOpen() {
    return this.hasModalTarget && !this.modalTarget.classList.contains("hidden")
  }

  /**
   * Handle input changes with debouncing
   * Debounces search by 300ms to avoid excessive API calls
   */
  handleInput(event) {
    const query = event.target.value.trim()

    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Debounce search by 300ms
    this.debounceTimer = setTimeout(() => {
      if (query.length >= 2) {
        this.performSearch(query)
      } else {
        this.clearResults()
        this.loadRecentSearches()
      }
    }, 300)
  }

  /**
   * Perform search via fetch API
   * @param {string} query - Search query string
   */
  async performSearch(query) {
    try {
      this.showLoading()

      const response = await fetch(`/search?q=${encodeURIComponent(query)}&scope=all`, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        throw new Error('Search request failed')
      }

      const results = await response.json()
      this.displayResults(results, query)
    } catch (error) {
      console.error("Search error:", error)
      this.showError()
    }
  }

  /**
   * Display search results grouped by category
   * @param {Object} results - Search results object with categories
   * @param {string} query - Original search query
   */
  displayResults(results, query) {
    let html = ""

    // Products
    if (results.products && results.products.length > 0) {
      html += this.renderSection("Products", results.products, (product) => `
        <a href="/products/${product.id}" class="block px-4 py-3 hover:bg-gray-50 transition-colors focus:outline-none focus:bg-gray-100">
          <div class="flex items-center">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(product.name)}</p>
              <p class="text-sm text-gray-500">${this.escapeHtml(product.sku)}</p>
            </div>
            <span class="ml-2 inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">
              ${this.escapeHtml(product.product_type || 'Product')}
            </span>
          </div>
        </a>
      `)
    }

    // Storage Locations
    if (results.storage && results.storage.length > 0) {
      html += this.renderSection("Storage Locations", results.storage, (storage) => `
        <a href="/storages/${storage.code}" class="block px-4 py-3 hover:bg-gray-50 transition-colors focus:outline-none focus:bg-gray-100">
          <div class="flex items-center">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(storage.name)}</p>
              <p class="text-sm text-gray-500">${this.escapeHtml(storage.code || '')}</p>
            </div>
          </div>
        </a>
      `)
    }

    // Product Attributes
    if (results.attributes && results.attributes.length > 0) {
      html += this.renderSection("Product Attributes", results.attributes, (attribute) => `
        <a href="/product_attributes/${attribute.id}" class="block px-4 py-3 hover:bg-gray-50 transition-colors focus:outline-none focus:bg-gray-100">
          <div class="flex items-center">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(attribute.name)}</p>
              <p class="text-sm text-gray-500">${this.escapeHtml(attribute.code || '')}</p>
            </div>
          </div>
        </a>
      `)
    }

    // Labels
    if (results.labels && results.labels.length > 0) {
      html += this.renderSection("Labels", results.labels, (label) => `
        <a href="/labels/${label.id}" class="block px-4 py-3 hover:bg-gray-50 transition-colors focus:outline-none focus:bg-gray-100">
          <div class="flex items-center">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(label.name)}</p>
            </div>
          </div>
        </a>
      `)
    }

    // Catalogs
    if (results.catalogs && results.catalogs.length > 0) {
      html += this.renderSection("Catalogs", results.catalogs, (catalog) => `
        <a href="/catalogs/${catalog.code}" class="block px-4 py-3 hover:bg-gray-50 transition-colors focus:outline-none focus:bg-gray-100">
          <div class="flex items-center">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(catalog.name)}</p>
              <p class="text-sm text-gray-500">${this.escapeHtml(catalog.code || '')}</p>
            </div>
          </div>
        </a>
      `)
    }

    // Empty state
    if (html === "") {
      html = `
        <div class="px-4 py-12 text-center">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="mt-4 text-sm text-gray-500">No results found for "${this.escapeHtml(query)}"</p>
          <p class="mt-2 text-xs text-gray-400">Try searching with different keywords</p>
        </div>
      `
    }

    this.resultsTarget.innerHTML = html
  }

  /**
   * Render a results section with title and items
   * @param {string} title - Section title
   * @param {Array} items - Array of items to render
   * @param {Function} itemRenderer - Function to render each item
   * @returns {string} HTML string for section
   */
  renderSection(title, items, itemRenderer) {
    return `
      <div class="py-2">
        <h3 class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">
          ${this.escapeHtml(title)}
        </h3>
        <div>
          ${items.map(itemRenderer).join('')}
        </div>
      </div>
    `
  }

  /**
   * Load recent searches from server
   */
  async loadRecentSearches() {
    try {
      const response = await fetch('/search/recent', {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        // Silently fail - recent searches are optional
        return
      }

      const recentSearches = await response.json()

      if (recentSearches && recentSearches.length > 0) {
        const html = `
          <div class="py-2">
            <h3 class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">
              Recent Searches
            </h3>
            <div>
              ${recentSearches.map(query => `
                <button
                  type="button"
                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 focus:outline-none focus:bg-gray-100 transition-colors"
                  data-action="click->global-search#fillSearch"
                  data-query="${this.escapeHtml(query)}">
                  <div class="flex items-center gap-2">
                    <svg class="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>${this.escapeHtml(query)}</span>
                  </div>
                </button>
              `).join('')}
            </div>
          </div>
        `
        this.resultsTarget.innerHTML = html
      }
    } catch (error) {
      console.error("Error loading recent searches:", error)
      // Silently fail - recent searches are optional
    }
  }

  /**
   * Fill search input with a recent search query
   * @param {Event} event - Click event
   */
  fillSearch(event) {
    const query = event.currentTarget.dataset.query
    if (query) {
      this.inputTarget.value = query
      this.performSearch(query)
    }
  }

  /**
   * Show loading state
   */
  showLoading() {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-12 text-center">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="mt-4 text-sm text-gray-500">Searching...</p>
      </div>
    `
  }

  /**
   * Show error state
   */
  showError() {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-12 text-center">
        <svg class="mx-auto h-12 w-12 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="mt-4 text-sm text-red-600">Error performing search</p>
        <p class="mt-2 text-xs text-gray-500">Please try again</p>
      </div>
    `
  }

  /**
   * Clear results area
   */
  clearResults() {
    this.resultsTarget.innerHTML = ""
  }

  /**
   * Escape HTML to prevent XSS
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Prevent dropdown close when clicking inside
   * @param {Event} event - Click event
   */
  preventClose(event) {
    event.stopPropagation()
  }

  /**
   * Handle clicks outside the dropdown
   * @param {Event} event - Click event
   */
  handleOutsideClick(event) {
    if (this.hasModalTarget && !this.modalTarget.contains(event.target)) {
      this.close()
    }
  }
}
