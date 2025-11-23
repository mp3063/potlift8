import { Controller } from "@hotwired/stimulus"

/**
 * Catalog tabs controller for Products::CatalogTabsComponent
 *
 * Handles tab switching between product and catalog attribute views:
 * - Tab switching with active state management
 * - URL hash persistence (e.g., #web-eur)
 * - localStorage persistence across page reloads
 * - Keyboard navigation (Arrow keys)
 * - ARIA attributes for accessibility
 *
 * @example
 *   <div data-controller="catalog-tabs">
 *     <button data-catalog-tabs-target="tab" data-tab-id="product">Product</button>
 *     <button data-catalog-tabs-target="tab" data-tab-id="web-eur">WEB-EUR</button>
 *     <div data-catalog-tabs-target="panel" data-panel-id="product">Content</div>
 *     <div data-catalog-tabs-target="panel" data-panel-id="web-eur">Content</div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["tab", "panel"]

  /**
   * Connect lifecycle - initialize tab state
   * Priority: URL hash > localStorage > default (product)
   */
  connect() {
    this.storageKey = "product_catalog_tab"

    // Set up keyboard navigation
    this.keyHandler = this.handleKeyboard.bind(this)
    this.element.addEventListener("keydown", this.keyHandler)

    // Determine initial tab to show
    // Don't update URL hash if showing default "product" tab on initial load
    if (this.showTabFromURL() || this.showTabFromStorage()) {
      // URL or storage had a specific tab, already activated with hash
    } else {
      // Default to product tab without adding hash to URL
      this.activateTab("product", false)
    }

    // Listen for hash changes (browser back/forward)
    this.hashChangeHandler = this.handleHashChange.bind(this)
    window.addEventListener("hashchange", this.hashChangeHandler)
  }

  /**
   * Disconnect lifecycle - cleanup event listeners
   */
  disconnect() {
    this.element.removeEventListener("keydown", this.keyHandler)
    window.removeEventListener("hashchange", this.hashChangeHandler)
  }

  /**
   * Show a specific tab by ID
   * Updates tab buttons, panels, URL hash, localStorage, and ARIA attributes
   *
   * @param {string} tabId - The tab ID to show
   * @param {boolean} updateUrl - Whether to update the URL hash (default: true)
   */
  activateTab(tabId, updateUrl = true) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabId === tabId

      // Update visual state
      if (isActive) {
        // Active tab: blue background, darker text, no border
        tab.classList.add("bg-blue-50", "text-blue-700", "border-transparent")
        tab.classList.remove("text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "hover:bg-gray-50")
      } else {
        // Inactive tab: gray text, hover effects
        tab.classList.remove("bg-blue-50", "text-blue-700")
        tab.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "hover:bg-gray-50")
      }

      // Update ARIA
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.panelId === tabId

      if (isActive) {
        panel.classList.remove("hidden")
        panel.setAttribute("aria-hidden", "false")
      } else {
        panel.classList.add("hidden")
        panel.setAttribute("aria-hidden", "true")
      }
    })

    // Update URL hash only if requested (skip for default tab on initial load)
    if (updateUrl) {
      this.updateHash(tabId)
    }

    // Save to localStorage
    this.saveToStorage(tabId)
  }

  /**
   * Handle tab click event
   * Extracts tab ID from clicked element and shows that tab
   *
   * @param {Event} event - Click event
   */
  showTab(event) {
    const tab = event.currentTarget
    const tabId = tab.dataset.tabId

    if (tabId) {
      // When user clicks a tab, always update URL (including removing hash for product tab)
      this.activateTab(tabId, true)
    }
  }

  /**
   * Show tab from URL hash
   * Returns true if hash was found and tab was shown
   *
   * @returns {boolean} True if tab was shown from hash
   */
  showTabFromURL() {
    const hash = window.location.hash.slice(1) // Remove '#'

    if (hash && this.tabExists(hash)) {
      this.activateTab(hash)
      return true
    }

    return false
  }

  /**
   * Show tab from localStorage
   * Returns true if saved tab was found and shown
   *
   * @returns {boolean} True if tab was shown from storage
   */
  showTabFromStorage() {
    const savedTab = localStorage.getItem(this.storageKey)

    if (savedTab && this.tabExists(savedTab)) {
      this.activateTab(savedTab)
      return true
    }

    return false
  }

  /**
   * Check if a tab with given ID exists
   *
   * @param {string} tabId - Tab ID to check
   * @returns {boolean} True if tab exists
   */
  tabExists(tabId) {
    return this.tabTargets.some(tab => tab.dataset.tabId === tabId)
  }

  /**
   * Update URL hash without scrolling or reloading
   * Removes hash for default "product" tab to keep URLs clean
   *
   * @param {string} tabId - Tab ID to set in hash
   */
  updateHash(tabId) {
    // Use history.replaceState to avoid triggering hashchange event
    // and prevent page scroll
    let newUrl
    if (tabId === "product") {
      // Remove hash for default tab
      newUrl = `${window.location.pathname}${window.location.search}`
    } else {
      newUrl = `${window.location.pathname}${window.location.search}#${tabId}`
    }
    history.replaceState(null, "", newUrl)
  }

  /**
   * Save current tab to localStorage
   * Don't save the default "product" tab to avoid hash pollution
   *
   * @param {string} tabId - Tab ID to save
   */
  saveToStorage(tabId) {
    try {
      if (tabId === "product") {
        // Remove from storage if it's the default tab
        localStorage.removeItem(this.storageKey)
      } else {
        localStorage.setItem(this.storageKey, tabId)
      }
    } catch (e) {
      // localStorage might be disabled or full - fail silently
      console.warn("Failed to save tab state to localStorage:", e)
    }
  }

  /**
   * Handle browser back/forward navigation
   * Shows tab based on new hash value
   */
  handleHashChange() {
    this.showTabFromURL()
  }

  /**
   * Handle keyboard navigation
   * - Arrow Left/Right: Navigate between tabs
   * - Home: Jump to first tab
   * - End: Jump to last tab
   *
   * @param {KeyboardEvent} event - Keyboard event
   */
  handleKeyboard(event) {
    // Only handle keyboard on tab buttons
    if (!event.target.hasAttribute("data-catalog-tabs-target") ||
        event.target.getAttribute("data-catalog-tabs-target") !== "tab") {
      return
    }

    const currentIndex = this.tabTargets.indexOf(event.target)
    let targetIndex = currentIndex

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        targetIndex = currentIndex > 0 ? currentIndex - 1 : this.tabTargets.length - 1
        break
      case "ArrowRight":
        event.preventDefault()
        targetIndex = currentIndex < this.tabTargets.length - 1 ? currentIndex + 1 : 0
        break
      case "Home":
        event.preventDefault()
        targetIndex = 0
        break
      case "End":
        event.preventDefault()
        targetIndex = this.tabTargets.length - 1
        break
      default:
        return
    }

    // Focus and show target tab
    const targetTab = this.tabTargets[targetIndex]
    if (targetTab) {
      targetTab.focus()
      this.activateTab(targetTab.dataset.tabId)
    }
  }

  /**
   * Open the "Add to Catalog" modal
   * Finds the modal controller and opens it
   */
  openAddModal() {
    // Find the specific "Add to Catalog" modal by its aria-labelledby attribute
    // We use aria-labelledby because there are multiple modals in the catalog tabs component
    // (one "Add to Catalog" modal and multiple "Add Attribute Override" modals per catalog)
    const modalBackdrop = this.element.querySelector('[aria-labelledby="add_to_catalog_modal-title"]')

    if (!modalBackdrop) {
      console.error('Add to Catalog modal backdrop not found')
      return
    }

    // Get the parent modal controller element
    const modal = modalBackdrop.closest('[data-controller="modal"]')

    if (!modal) {
      console.error('Modal controller element not found')
      return
    }

    // Get the modal controller instance
    const modalController = this.application.getControllerForElementAndIdentifier(modal, "modal")

    if (!modalController) {
      console.error('Modal controller not found for element:', modal)
      return
    }

    // Open the modal
    modalController.open()
  }
}
