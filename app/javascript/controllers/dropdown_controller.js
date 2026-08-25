import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.keyHandler = this.handleKeydown.bind(this)
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    this.removeEventListeners()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const isHidden = this.menuTarget.classList.contains("hidden")

    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    setTimeout(() => {
      const firstItem = this.menuTarget.querySelector('[role="menuitem"]')
      if (firstItem) firstItem.focus()
    }, 10)

    document.addEventListener("keydown", this.keyHandler)
    document.addEventListener("click", this.outsideClickHandler)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.buttonTarget.focus()
    this.removeEventListeners()
  }

  handleKeydown(event) {
    if (this.menuTarget.classList.contains("hidden")) return

    switch(event.key) {
      case "Escape":
        event.preventDefault()
        this.close()
        break
      case "ArrowDown":
        event.preventDefault()
        this.focusNextItem()
        break
      case "ArrowUp":
        event.preventDefault()
        this.focusPreviousItem()
        break
      case "Home":
        event.preventDefault()
        this.focusFirstItem()
        break
      case "End":
        event.preventDefault()
        this.focusLastItem()
        break
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  focusNextItem() {
    const items = this.getFocusableItems()
    const currentIndex = items.indexOf(document.activeElement)
    const nextIndex = (currentIndex + 1) % items.length
    items[nextIndex].focus()
  }

  focusPreviousItem() {
    const items = this.getFocusableItems()
    const currentIndex = items.indexOf(document.activeElement)
    const prevIndex = currentIndex <= 0 ? items.length - 1 : currentIndex - 1
    items[prevIndex].focus()
  }

  focusFirstItem() {
    const items = this.getFocusableItems()
    if (items.length > 0) items[0].focus()
  }

  focusLastItem() {
    const items = this.getFocusableItems()
    if (items.length > 0) items[items.length - 1].focus()
  }

  getFocusableItems() {
    return Array.from(this.menuTarget.querySelectorAll('[role="menuitem"]'))
  }

  removeEventListeners() {
    document.removeEventListener("keydown", this.keyHandler)
    document.removeEventListener("click", this.outsideClickHandler)
  }
}
