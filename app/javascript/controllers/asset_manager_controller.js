import { Controller } from "@hotwired/stimulus"

/**
 * Asset Manager Controller
 *
 * Manages the asset gallery view with tab navigation and bulk operations.
 * Handles switching between documents, videos, and links tabs, and manages
 * selection state for bulk delete/download operations.
 *
 * Features:
 * - Tab switching between asset types (documents/videos/links)
 * - Bulk selection with select all/none functionality
 * - Keyboard navigation (Arrow keys, Home, End)
 * - ARIA state management for accessibility
 * - Selection counter display
 * - Enable/disable bulk action buttons based on selection
 *
 * Targets:
 * - tab: Individual tab buttons
 * - panel: Tab panel content areas
 * - checkbox: Asset selection checkboxes
 * - selectAllCheckbox: Master checkbox for selecting all assets
 * - bulkActions: Container for bulk action buttons
 * - selectionCounter: Display for number of selected items
 *
 * Values:
 * - currentTab: Currently active tab identifier (default: "documents")
 *
 * @example
 *   <div data-controller="asset-manager">
 *     <button data-asset-manager-target="tab"
 *             data-tab-id="documents"
 *             data-action="click->asset-manager#switchTab">
 *       Documents
 *     </button>
 *     <div data-asset-manager-target="panel" data-tab-id="documents">
 *       <input type="checkbox" data-asset-manager-target="checkbox">
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "tab",
    "panel",
    "checkbox",
    "selectAllCheckbox",
    "bulkActions",
    "selectionCounter"
  ]

  static values = {
    currentTab: { type: String, default: "documents" }
  }

  connect() {
    console.log("Asset manager controller connected")
    this.setupKeyboardNavigation()
    this.updateSelectionState()

    // Activate initial tab
    const initialTab = this.tabTargets.find(tab =>
      tab.dataset.tabId === this.currentTabValue
    )
    if (initialTab) {
      this.switchToTab(initialTab)
    }
  }

  /**
   * Setup keyboard navigation for tabs
   */
  setupKeyboardNavigation() {
    this.tabTargets.forEach(tab => {
      tab.addEventListener("keydown", this.handleKeydown.bind(this))
    })
  }

  /**
   * Handle keyboard navigation
   * @param {KeyboardEvent} event
   */
  handleKeydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.target)

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        this.focusPreviousTab(tabs, currentIndex)
        break

      case "ArrowRight":
        event.preventDefault()
        this.focusNextTab(tabs, currentIndex)
        break

      case "Home":
        event.preventDefault()
        this.focusTab(tabs[0])
        break

      case "End":
        event.preventDefault()
        this.focusTab(tabs[tabs.length - 1])
        break
    }
  }

  /**
   * Focus the previous tab (wraps around)
   */
  focusPreviousTab(tabs, currentIndex) {
    const prevIndex = currentIndex === 0 ? tabs.length - 1 : currentIndex - 1
    this.focusTab(tabs[prevIndex])
  }

  /**
   * Focus the next tab (wraps around)
   */
  focusNextTab(tabs, currentIndex) {
    const nextIndex = currentIndex === tabs.length - 1 ? 0 : currentIndex + 1
    this.focusTab(tabs[nextIndex])
  }

  /**
   * Focus a specific tab and activate it
   * @param {HTMLElement} tab
   */
  focusTab(tab) {
    tab.focus()
    this.switchToTab(tab)
  }

  /**
   * Switch to a tab (triggered by click)
   * @param {Event} event
   */
  switchTab(event) {
    event.preventDefault()
    this.switchToTab(event.currentTarget)
  }

  /**
   * Switch to a specific tab and show its panel
   * @param {HTMLElement} tab
   */
  switchToTab(tab) {
    const tabId = tab.dataset.tabId

    if (!tabId) {
      console.error("Tab missing data-tab-id attribute")
      return
    }

    console.log("Switching to tab:", tabId)

    // Update current tab value
    this.currentTabValue = tabId

    // Deactivate all tabs
    this.tabTargets.forEach(t => {
      t.setAttribute("aria-selected", "false")
      t.classList.remove("border-blue-600", "text-blue-600")
      t.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
    })

    // Activate the selected tab
    tab.setAttribute("aria-selected", "true")
    tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
    tab.classList.add("border-blue-600", "text-blue-600")

    // Hide all panels
    this.panelTargets.forEach(panel => {
      panel.classList.add("hidden")
      panel.setAttribute("aria-hidden", "true")
    })

    // Show the selected panel
    const selectedPanel = this.panelTargets.find(p => p.dataset.tabId === tabId)
    if (selectedPanel) {
      selectedPanel.classList.remove("hidden")
      selectedPanel.setAttribute("aria-hidden", "false")
    } else {
      console.error("Panel not found for tab ID:", tabId)
    }

    // Reset selection state when switching tabs
    this.clearSelection()
  }

  /**
   * Toggle individual checkbox selection
   * @param {Event} event
   */
  toggleSelection(event) {
    this.updateSelectionState()
  }

  /**
   * Toggle select all checkboxes in current tab
   * @param {Event} event
   */
  toggleSelectAll(event) {
    const checked = event.target.checked
    const currentPanel = this.getCurrentPanel()

    if (currentPanel) {
      const checkboxes = currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]')
      checkboxes.forEach(checkbox => {
        checkbox.checked = checked
      })
    }

    this.updateSelectionState()
  }

  /**
   * Get currently visible panel
   * @returns {HTMLElement|null}
   */
  getCurrentPanel() {
    return this.panelTargets.find(p =>
      p.dataset.tabId === this.currentTabValue && !p.classList.contains("hidden")
    )
  }

  /**
   * Get selected checkboxes in current panel
   * @returns {HTMLElement[]}
   */
  getSelectedCheckboxes() {
    const currentPanel = this.getCurrentPanel()
    if (!currentPanel) return []

    return Array.from(
      currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]:checked')
    )
  }

  /**
   * Get all checkboxes in current panel
   * @returns {HTMLElement[]}
   */
  getAllCheckboxes() {
    const currentPanel = this.getCurrentPanel()
    if (!currentPanel) return []

    return Array.from(
      currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]')
    )
  }

  /**
   * Update selection state (counter, select all checkbox, bulk actions)
   */
  updateSelectionState() {
    const selected = this.getSelectedCheckboxes()
    const total = this.getAllCheckboxes()
    const selectedCount = selected.length

    // Update selection counter
    if (this.hasSelectionCounterTarget) {
      this.selectionCounterTarget.textContent = selectedCount

      // Update aria-label for screen readers
      this.selectionCounterTarget.setAttribute(
        "aria-label",
        `${selectedCount} asset${selectedCount !== 1 ? 's' : ''} selected`
      )
    }

    // Update select all checkbox state
    if (this.hasSelectAllCheckboxTarget && total.length > 0) {
      if (selectedCount === 0) {
        this.selectAllCheckboxTarget.checked = false
        this.selectAllCheckboxTarget.indeterminate = false
      } else if (selectedCount === total.length) {
        this.selectAllCheckboxTarget.checked = true
        this.selectAllCheckboxTarget.indeterminate = false
      } else {
        this.selectAllCheckboxTarget.checked = false
        this.selectAllCheckboxTarget.indeterminate = true
      }
    }

    // Enable/disable bulk actions
    if (this.hasBulkActionsTarget) {
      const buttons = this.bulkActionsTarget.querySelectorAll("button")
      buttons.forEach(button => {
        if (selectedCount > 0) {
          button.disabled = false
          button.classList.remove("opacity-50", "cursor-not-allowed")
        } else {
          button.disabled = true
          button.classList.add("opacity-50", "cursor-not-allowed")
        }
      })
    }
  }

  /**
   * Clear all selections in current panel
   */
  clearSelection() {
    const currentPanel = this.getCurrentPanel()
    if (currentPanel) {
      const checkboxes = currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]')
      checkboxes.forEach(checkbox => {
        checkbox.checked = false
      })
    }

    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    }

    this.updateSelectionState()
  }

  /**
   * Get selected asset IDs for bulk operations
   * @returns {string[]}
   */
  getSelectedAssetIds() {
    return this.getSelectedCheckboxes().map(checkbox => checkbox.value)
  }

  /**
   * Handle bulk delete action
   * @param {Event} event
   */
  bulkDelete(event) {
    event.preventDefault()

    const selectedIds = this.getSelectedAssetIds()
    if (selectedIds.length === 0) {
      return
    }

    const count = selectedIds.length
    const assetType = this.currentTabValue.slice(0, -1) // Remove trailing 's'

    if (!confirm(`Are you sure you want to delete ${count} ${assetType}${count !== 1 ? 's' : ''}?`)) {
      return
    }

    // Get delete URL from button
    const deleteUrl = event.currentTarget.dataset.deleteUrl

    if (!deleteUrl) {
      console.error("Delete URL not found")
      return
    }

    // Get CSRF token
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      return
    }

    // Show loading state
    this.showLoadingState()

    // Make DELETE request
    fetch(deleteUrl, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ asset_ids: selectedIds })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      // Reload page to show updated assets
      window.location.reload()
    })
    .catch(error => {
      console.error("Error deleting assets:", error)
      this.hideLoadingState()
      alert("Failed to delete assets. Please try again.")
    })
  }

  /**
   * Show loading state
   */
  showLoadingState() {
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.classList.add("opacity-50", "pointer-events-none")
    }

    const currentPanel = this.getCurrentPanel()
    if (currentPanel) {
      currentPanel.classList.add("opacity-50", "pointer-events-none")
    }
  }

  /**
   * Hide loading state
   */
  hideLoadingState() {
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.classList.remove("opacity-50", "pointer-events-none")
    }

    const currentPanel = this.getCurrentPanel()
    if (currentPanel) {
      currentPanel.classList.remove("opacity-50", "pointer-events-none")
    }
  }
}
