import { Controller } from "@hotwired/stimulus"

// Dropdown menu controller with keyboard navigation support
//
// Handles opening/closing dropdown menus with outside click detection and keyboard navigation
// Used for: user menu, company selector, and other dropdown menus
//
// Targets:
//   - menu: The dropdown menu element to show/hide
//   - button: The button that triggers the dropdown
//
// Actions:
//   - toggle: Toggle dropdown open/closed state
//   - open: Open the dropdown
//   - close: Close the dropdown
//
// Keyboard Navigation:
//   - Escape: Close dropdown
//   - Arrow Down: Move to next menu item
//   - Arrow Up: Move to previous menu item
//   - Home: Focus first menu item
//   - End: Focus last menu item
//
// Usage:
//   <div data-controller="dropdown">
//     <button data-action="click->dropdown#toggle" data-dropdown-target="button">Toggle</button>
//     <div data-dropdown-target="menu" class="hidden" role="menu">
//       <a href="#" role="menuitem">Item 1</a>
//       <a href="#" role="menuitem">Item 2</a>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.keyHandler = this.handleKeydown.bind(this)
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    this.removeEventListeners()
  }

  // Toggle dropdown open/closed state
  //
  // @param {Event} event - Click event
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

  // Open the dropdown menu
  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    // Focus first menu item
    setTimeout(() => {
      const firstItem = this.menuTarget.querySelector('[role="menuitem"]')
      if (firstItem) firstItem.focus()
    }, 10)

    // Add event listeners
    document.addEventListener("keydown", this.keyHandler)
    document.addEventListener("click", this.outsideClickHandler)
  }

  // Close the dropdown menu
  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.buttonTarget.focus()
    this.removeEventListeners()
  }

  // Handle keyboard navigation
  //
  // @param {KeyboardEvent} event - Keyboard event
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

  // Handle clicks outside the dropdown to close it
  //
  // @param {Event} event - Click event
  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  // Focus next menu item (wraps to first)
  focusNextItem() {
    const items = this.getFocusableItems()
    const currentIndex = items.indexOf(document.activeElement)
    const nextIndex = (currentIndex + 1) % items.length
    items[nextIndex].focus()
  }

  // Focus previous menu item (wraps to last)
  focusPreviousItem() {
    const items = this.getFocusableItems()
    const currentIndex = items.indexOf(document.activeElement)
    const prevIndex = currentIndex <= 0 ? items.length - 1 : currentIndex - 1
    items[prevIndex].focus()
  }

  // Focus first menu item
  focusFirstItem() {
    const items = this.getFocusableItems()
    if (items.length > 0) items[0].focus()
  }

  // Focus last menu item
  focusLastItem() {
    const items = this.getFocusableItems()
    if (items.length > 0) items[items.length - 1].focus()
  }

  // Get all focusable menu items
  //
  // @returns {Array<Element>} Array of focusable menu items
  getFocusableItems() {
    return Array.from(this.menuTarget.querySelectorAll('[role="menuitem"]'))
  }

  // Remove event listeners
  removeEventListeners() {
    document.removeEventListener("keydown", this.keyHandler)
    document.removeEventListener("click", this.outsideClickHandler)
  }
}
