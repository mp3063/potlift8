import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.storageKey = "product_catalog_tab"

    this.keyHandler = this.handleKeyboard.bind(this)
    this.element.addEventListener("keydown", this.keyHandler)

    // Determine initial tab to show
    // Don't update URL hash if showing default "product" tab on initial load
    if (this.showTabFromURL() || this.showTabFromStorage()) {
    } else {
      this.activateTab("product", false)
    }

    this.hashChangeHandler = this.handleHashChange.bind(this)
    window.addEventListener("hashchange", this.hashChangeHandler)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.keyHandler)
    window.removeEventListener("hashchange", this.hashChangeHandler)
  }

  activateTab(tabId, updateUrl = true) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabId === tabId

      if (isActive) {
        tab.classList.add("bg-blue-50", "text-blue-700", "border-transparent")
        tab.classList.remove("text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "hover:bg-gray-50")
      } else {
        tab.classList.remove("bg-blue-50", "text-blue-700")
        tab.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "hover:bg-gray-50")
      }

      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

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

    if (updateUrl) {
      this.updateHash(tabId)
    }

    this.saveToStorage(tabId)
  }

  showTab(event) {
    const tab = event.currentTarget
    const tabId = tab.dataset.tabId

    if (tabId) {
      this.activateTab(tabId, true)
    }
  }

  showTabFromURL() {
    const hash = window.location.hash.slice(1)

    if (hash && this.tabExists(hash)) {
      this.activateTab(hash)
      return true
    }

    return false
  }

  showTabFromStorage() {
    const savedTab = localStorage.getItem(this.storageKey)

    if (savedTab && this.tabExists(savedTab)) {
      this.activateTab(savedTab)
      return true
    }

    return false
  }

  tabExists(tabId) {
    return this.tabTargets.some(tab => tab.dataset.tabId === tabId)
  }

  updateHash(tabId) {
    // Use history.replaceState to avoid triggering hashchange event
    // and prevent page scroll
    let newUrl
    if (tabId === "product") {
      newUrl = `${window.location.pathname}${window.location.search}`
    } else {
      newUrl = `${window.location.pathname}${window.location.search}#${tabId}`
    }
    history.replaceState(null, "", newUrl)
  }

  /**
   * Save current tab to localStorage
   * Don't save the default "product" tab to avoid hash pollution
   */
  saveToStorage(tabId) {
    try {
      if (tabId === "product") {
        localStorage.removeItem(this.storageKey)
      } else {
        localStorage.setItem(this.storageKey, tabId)
      }
    } catch (e) {
      console.warn("Failed to save tab state to localStorage:", e)
    }
  }

  handleHashChange() {
    this.showTabFromURL()
  }

  handleKeyboard(event) {
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

    const targetTab = this.tabTargets[targetIndex]
    if (targetTab) {
      targetTab.focus()
      this.activateTab(targetTab.dataset.tabId)
    }
  }

  openAddModal() {
    // Find the specific "Add to Catalog" modal by its aria-labelledby attribute
    // We use aria-labelledby because there are multiple modals in the catalog tabs component
    // (one "Add to Catalog" modal and multiple "Add Attribute Override" modals per catalog)
    const modalBackdrop = this.element.querySelector('[aria-labelledby="add_to_catalog_modal-title"]')

    if (!modalBackdrop) {
      console.error('Add to Catalog modal backdrop not found')
      return
    }

    const modal = modalBackdrop.closest('[data-controller="modal"]')

    if (!modal) {
      console.error('Modal controller element not found')
      return
    }

    const modalController = this.application.getControllerForElementAndIdentifier(modal, "modal")

    if (!modalController) {
      console.error('Modal controller not found for element:', modal)
      return
    }

    modalController.open()
  }
}
