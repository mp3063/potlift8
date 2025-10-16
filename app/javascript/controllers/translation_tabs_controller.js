import { Controller } from "@hotwired/stimulus"

/**
 * Translation Tabs Controller
 *
 * Manages tab navigation for multi-locale translation forms.
 * Handles tab switching with keyboard navigation and ARIA state management.
 *
 * Features:
 * - Tab switching on click
 * - Keyboard navigation (Arrow Left/Right, Home, End)
 * - ARIA attributes for accessibility
 * - Active tab highlighting (blue-600)
 * - Show/hide panels based on active tab
 * - Focus management
 *
 * @example
 *   <div data-controller="translation-tabs">
 *     <button data-translation-tabs-target="tab"
 *             data-locale="en"
 *             data-action="click->translation-tabs#switchTab">
 *       English
 *     </button>
 *     <div data-translation-tabs-target="panel" data-locale="en">
 *       <!-- Content -->
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    console.log("Translation tabs controller connected")
    this.setupKeyboardNavigation()
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
    const locale = tab.dataset.locale

    if (!locale) {
      console.error("Tab missing data-locale attribute")
      return
    }

    console.log("Switching to locale:", locale)

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
    })

    // Show the selected panel
    const selectedPanel = this.panelTargets.find(p => p.dataset.locale === locale)
    if (selectedPanel) {
      selectedPanel.classList.remove("hidden")
    } else {
      console.error("Panel not found for locale:", locale)
    }
  }
}
