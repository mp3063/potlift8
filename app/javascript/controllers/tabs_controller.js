import { Controller } from "@hotwired/stimulus"

/**
 * Tabs Controller
 *
 * Simple tabbed navigation controller that handles tab switching
 * with proper ARIA accessibility support.
 *
 * Usage:
 * <div data-controller="tabs">
 *   <button data-tabs-target="tab" data-action="click->tabs#switch" data-tab-id="documents">Documents</button>
 *   <button data-tabs-target="tab" data-action="click->tabs#switch" data-tab-id="videos">Videos</button>
 *
 *   <div data-tabs-target="panel" data-panel-id="documents">Documents content</div>
 *   <div data-tabs-target="panel" data-panel-id="videos" class="hidden">Videos content</div>
 * </div>
 */
export default class extends Controller {
  static targets = ["tab", "panel"]

  // Active tab styling classes
  static values = {
    activeClasses: { type: String, default: "border-blue-600 text-blue-600" },
    inactiveClasses: { type: String, default: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700" }
  }

  connect() {
    // Initialize first tab as active if none selected
    if (!this.hasActiveTab()) {
      this.activateFirstTab()
    }
  }

  /**
   * Switch to clicked tab
   * @param {Event} event - Click event from tab button
   */
  switch(event) {
    event.preventDefault()
    const clickedTab = event.currentTarget
    const tabId = clickedTab.dataset.tabId

    this.activateTab(tabId)
  }

  /**
   * Activate a specific tab by ID
   * @param {string} tabId - The tab identifier
   */
  activateTab(tabId) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabId === tabId

      // Remove both class sets then add appropriate ones
      this.activeClassesValue.split(" ").forEach(cls => tab.classList.remove(cls))
      this.inactiveClassesValue.split(" ").forEach(cls => tab.classList.remove(cls))

      if (isActive) {
        this.activeClassesValue.split(" ").forEach(cls => tab.classList.add(cls))
        tab.setAttribute("aria-current", "page")
      } else {
        this.inactiveClassesValue.split(" ").forEach(cls => tab.classList.add(cls))
        tab.removeAttribute("aria-current")
      }
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
  }

  /**
   * Check if any tab is currently active
   * @returns {boolean}
   */
  hasActiveTab() {
    return this.tabTargets.some(tab => tab.getAttribute("aria-current") === "page")
  }

  /**
   * Activate the first tab by default
   */
  activateFirstTab() {
    if (this.tabTargets.length > 0) {
      const firstTabId = this.tabTargets[0].dataset.tabId
      this.activateTab(firstTabId)
    }
  }

  /**
   * Keyboard navigation for tabs
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(document.activeElement)

    if (currentIndex === -1) return

    let newIndex

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.length - 1
        break
      case "ArrowRight":
        event.preventDefault()
        newIndex = currentIndex < tabs.length - 1 ? currentIndex + 1 : 0
        break
      case "Home":
        event.preventDefault()
        newIndex = 0
        break
      case "End":
        event.preventDefault()
        newIndex = tabs.length - 1
        break
      default:
        return
    }

    tabs[newIndex].focus()
    this.activateTab(tabs[newIndex].dataset.tabId)
  }
}
