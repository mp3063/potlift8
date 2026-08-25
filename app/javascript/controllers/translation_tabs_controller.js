import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    console.log("Translation tabs controller connected")
    this.setupKeyboardNavigation()
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
    const locale = tab.dataset.locale

    if (!locale) {
      console.error("Tab missing data-locale attribute")
      return
    }

    console.log("Switching to locale:", locale)

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
    })

    const selectedPanel = this.panelTargets.find(p => p.dataset.locale === locale)
    if (selectedPanel) {
      selectedPanel.classList.remove("hidden")
    } else {
      console.error("Panel not found for locale:", locale)
    }
  }
}
