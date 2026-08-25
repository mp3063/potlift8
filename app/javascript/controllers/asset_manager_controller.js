import { Controller } from "@hotwired/stimulus"

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

    const initialTab = this.tabTargets.find(tab =>
      tab.dataset.tabId === this.currentTabValue
    )
    if (initialTab) {
      this.switchToTab(initialTab)
    }
  }

  setupKeyboardNavigation() {
    this.tabTargets.forEach(tab => {
      tab.addEventListener("keydown", this.handleKeydown.bind(this))
    })
  }

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

  focusPreviousTab(tabs, currentIndex) {
    const prevIndex = currentIndex === 0 ? tabs.length - 1 : currentIndex - 1
    this.focusTab(tabs[prevIndex])
  }

  focusNextTab(tabs, currentIndex) {
    const nextIndex = currentIndex === tabs.length - 1 ? 0 : currentIndex + 1
    this.focusTab(tabs[nextIndex])
  }

  focusTab(tab) {
    tab.focus()
    this.switchToTab(tab)
  }

  switchTab(event) {
    event.preventDefault()
    this.switchToTab(event.currentTarget)
  }

  switchToTab(tab) {
    const tabId = tab.dataset.tabId

    if (!tabId) {
      console.error("Tab missing data-tab-id attribute")
      return
    }

    console.log("Switching to tab:", tabId)

    this.currentTabValue = tabId

    this.tabTargets.forEach(t => {
      t.setAttribute("aria-selected", "false")
      t.classList.remove("border-blue-600", "text-blue-600")
      t.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
    })

    tab.setAttribute("aria-selected", "true")
    tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
    tab.classList.add("border-blue-600", "text-blue-600")

    this.panelTargets.forEach(panel => {
      panel.classList.add("hidden")
      panel.setAttribute("aria-hidden", "true")
    })

    const selectedPanel = this.panelTargets.find(p => p.dataset.tabId === tabId)
    if (selectedPanel) {
      selectedPanel.classList.remove("hidden")
      selectedPanel.setAttribute("aria-hidden", "false")
    } else {
      console.error("Panel not found for tab ID:", tabId)
    }

    this.clearSelection()
  }

  toggleSelection(event) {
    this.updateSelectionState()
  }

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

  getCurrentPanel() {
    return this.panelTargets.find(p =>
      p.dataset.tabId === this.currentTabValue && !p.classList.contains("hidden")
    )
  }

  getSelectedCheckboxes() {
    const currentPanel = this.getCurrentPanel()
    if (!currentPanel) return []

    return Array.from(
      currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]:checked')
    )
  }

  getAllCheckboxes() {
    const currentPanel = this.getCurrentPanel()
    if (!currentPanel) return []

    return Array.from(
      currentPanel.querySelectorAll('input[type="checkbox"][data-asset-manager-target="checkbox"]')
    )
  }

  updateSelectionState() {
    const selected = this.getSelectedCheckboxes()
    const total = this.getAllCheckboxes()
    const selectedCount = selected.length

    if (this.hasSelectionCounterTarget) {
      this.selectionCounterTarget.textContent = selectedCount

      // Update aria-label for screen readers
      this.selectionCounterTarget.setAttribute(
        "aria-label",
        `${selectedCount} asset${selectedCount !== 1 ? 's' : ''} selected`
      )
    }

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

  getSelectedAssetIds() {
    return this.getSelectedCheckboxes().map(checkbox => checkbox.value)
  }

  bulkDelete(event) {
    event.preventDefault()

    const selectedIds = this.getSelectedAssetIds()
    if (selectedIds.length === 0) {
      return
    }

    const count = selectedIds.length
    const assetType = this.currentTabValue.slice(0, -1)

    if (!confirm(`Are you sure you want to delete ${count} ${assetType}${count !== 1 ? 's' : ''}?`)) {
      return
    }

    const deleteUrl = event.currentTarget.dataset.deleteUrl

    if (!deleteUrl) {
      console.error("Delete URL not found")
      return
    }

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    if (!csrfToken) {
      console.error("CSRF token not found")
      return
    }

    this.showLoadingState()

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
      window.location.reload()
    })
    .catch(error => {
      console.error("Error deleting assets:", error)
      this.hideLoadingState()
      alert("Failed to delete assets. Please try again.")
    })
  }

  showLoadingState() {
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.classList.add("opacity-50", "pointer-events-none")
    }

    const currentPanel = this.getCurrentPanel()
    if (currentPanel) {
      currentPanel.classList.add("opacity-50", "pointer-events-none")
    }
  }

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
