import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  static values = {
    activeClasses: { type: String, default: "border-blue-600 text-blue-600" },
    inactiveClasses: { type: String, default: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700" }
  }

  connect() {
    if (!this.hasActiveTab()) {
      this.activateFirstTab()
    }
  }

  switch(event) {
    event.preventDefault()
    const clickedTab = event.currentTarget
    const tabId = clickedTab.dataset.tabId

    this.activateTab(tabId)
  }

  activateTab(tabId) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabId === tabId

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

  hasActiveTab() {
    return this.tabTargets.some(tab => tab.getAttribute("aria-current") === "page")
  }

  activateFirstTab() {
    if (this.tabTargets.length > 0) {
      const firstTabId = this.tabTargets[0].dataset.tabId
      this.activateTab(firstTabId)
    }
  }

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
