import { Controller } from "@hotwired/stimulus"

/**
 * Label Form Selector Controller
 *
 * Manages label selection in product forms with search, add/remove functionality,
 * and accessibility support. Handles dynamic updates to hidden form inputs for
 * Rails form submission.
 *
 * Features:
 * - Search/filter labels by name
 * - Add labels by clicking (prevents duplicates)
 * - Remove labels with smooth animations
 * - Keyboard navigation support (Tab, Enter, Escape)
 * - Hidden checkboxes for form submission
 * - Accessibility announcements
 * - Empty state management
 *
 * Targets:
 * - search: Search input field
 * - labelList: Container for available labels
 * - labelOption: Individual label button (multiple)
 * - emptyState: Empty state message for no search results
 * - selectedContainer: Container for selected label tags
 * - emptyMessage: Empty message when no labels selected
 * - hiddenInputs: Container for hidden form checkboxes
 *
 * @example
 *   <div data-controller="label-form-selector">
 *     <input data-label-form-selector-target="search"
 *            data-action="input->label-form-selector#filterLabels">
 *
 *     <div data-label-form-selector-target="labelList">
 *       <button data-label-id="1"
 *               data-label-name="Electronics"
 *               data-label-color="#3b82f6"
 *               data-action="click->label-form-selector#addLabel"
 *               data-label-form-selector-target="labelOption">
 *         Electronics
 *       </button>
 *     </div>
 *
 *     <div data-label-form-selector-target="selectedContainer"></div>
 *     <div data-label-form-selector-target="hiddenInputs"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "search",
    "labelList",
    "labelOption",
    "emptyState",
    "selectedContainer",
    "emptyMessage",
    "hiddenInputs"
  ]

  /**
   * Initialize controller
   * Sets up selected labels set for duplicate prevention
   */
  connect() {
    // Track selected label IDs to prevent duplicates
    this.selectedLabels = new Set()

    // Initialize from existing selected labels in the DOM
    this.initializeSelectedLabels()

    // Log connection for debugging
    console.log("Label form selector controller connected")
  }

  /**
   * Initialize selected labels from existing DOM elements
   * Called on connect to populate selectedLabels set from pre-rendered labels
   */
  initializeSelectedLabels() {
    const existingTags = this.selectedContainerTarget.querySelectorAll("[data-label-id]")

    existingTags.forEach(tag => {
      const labelId = tag.dataset.labelId
      if (labelId) {
        this.selectedLabels.add(labelId)
      }
    })

    console.log("Initialized with selected labels:", Array.from(this.selectedLabels))
  }

  /**
   * Filter labels based on search input
   * Shows/hides label options and manages empty state
   *
   * @param {Event} event - Input event from search field
   */
  filterLabels(event) {
    const searchTerm = event.target.value.toLowerCase().trim()
    let visibleCount = 0

    this.labelOptionTargets.forEach(option => {
      const labelName = option.dataset.labelName.toLowerCase()
      const matches = labelName.includes(searchTerm)

      if (matches) {
        option.classList.remove("hidden")
        visibleCount++
      } else {
        option.classList.add("hidden")
      }
    })

    // Manage empty state visibility
    if (visibleCount === 0 && searchTerm !== "") {
      this.showEmptyState()
    } else {
      this.hideEmptyState()
    }
  }

  /**
   * Add a label to the selection
   * Creates tag element and updates hidden inputs
   *
   * @param {Event} event - Click event from label option button
   */
  addLabel(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const labelId = button.dataset.labelId
    const labelName = button.dataset.labelName
    const labelColor = button.dataset.labelColor || "#2563eb"

    // Prevent duplicate selections
    if (this.selectedLabels.has(labelId)) {
      this.announceToScreenReader(`Label ${labelName} is already selected`)
      return
    }

    // Add to selected set
    this.selectedLabels.add(labelId)

    // Create tag element
    this.createLabelTag(labelId, labelName, labelColor)

    // Create hidden checkbox for form submission
    this.createHiddenCheckbox(labelId)

    // Update empty message visibility
    this.updateEmptyMessage()

    // Announce to screen readers
    this.announceToScreenReader(`Label ${labelName} added`)

    // Clear search input
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.searchTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    // Optionally disable the button in available labels
    button.disabled = true
    button.classList.add("opacity-50", "cursor-not-allowed")
    button.setAttribute("aria-disabled", "true")
  }

  /**
   * Remove a label from the selection
   * Removes tag element and updates hidden inputs
   *
   * @param {Event} event - Click event from remove button
   */
  removeLabel(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const labelId = button.dataset.labelId
    const tagElement = button.closest("[data-label-id]")
    const labelName = tagElement.querySelector("span:not(.sr-only)").textContent.trim()

    if (!tagElement) {
      console.error("Could not find label tag element")
      return
    }

    // Remove from selected set
    this.selectedLabels.delete(labelId)

    // Animate removal
    tagElement.style.transition = "opacity 150ms ease-out, transform 150ms ease-out"
    tagElement.style.opacity = "0"
    tagElement.style.transform = "scale(0.9)"

    setTimeout(() => {
      tagElement.remove()

      // Update empty message visibility
      this.updateEmptyMessage()

      // Announce to screen readers
      this.announceToScreenReader(`Label ${labelName} removed`)
    }, 150)

    // Remove hidden checkbox
    this.removeHiddenCheckbox(labelId)

    // Re-enable the button in available labels
    const availableButton = Array.from(this.labelOptionTargets).find(
      btn => btn.dataset.labelId === labelId
    )

    if (availableButton) {
      availableButton.disabled = false
      availableButton.classList.remove("opacity-50", "cursor-not-allowed")
      availableButton.removeAttribute("aria-disabled")
    }
  }

  /**
   * Create a label tag element in the selected container
   *
   * @param {string} labelId - Label ID
   * @param {string} labelName - Label display name
   * @param {string} labelColor - Label color (hex)
   */
  createLabelTag(labelId, labelName, labelColor) {
    const tag = document.createElement("span")
    tag.className = "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm bg-blue-100 text-blue-800 border border-blue-200 transition-all duration-150"
    tag.setAttribute("data-label-id", labelId)
    tag.setAttribute("role", "listitem")
    tag.style.opacity = "0"
    tag.style.transform = "scale(0.9)"

    tag.innerHTML = `
      <span class="h-2 w-2 rounded-full flex-shrink-0" style="background-color: ${this.escapeHtml(labelColor)}" aria-hidden="true"></span>
      <span class="font-medium">${this.escapeHtml(labelName)}</span>
      <button
        type="button"
        class="ml-1 inline-flex items-center justify-center h-4 w-4 rounded-full hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 transition-colors"
        data-action="click->label-form-selector#removeLabel"
        data-label-id="${labelId}"
        aria-label="Remove label ${this.escapeHtml(labelName)}"
      >
        <svg class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
        </svg>
      </button>
    `

    this.selectedContainerTarget.appendChild(tag)

    // Animate in
    requestAnimationFrame(() => {
      tag.style.opacity = "1"
      tag.style.transform = "scale(1)"
    })
  }

  /**
   * Create hidden checkbox for form submission
   *
   * @param {string} labelId - Label ID to create checkbox for
   */
  createHiddenCheckbox(labelId) {
    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.name = "product[label_ids][]"
    checkbox.value = labelId
    checkbox.checked = true
    checkbox.className = "label-checkbox"
    checkbox.setAttribute("data-label-id", labelId)

    this.hiddenInputsTarget.appendChild(checkbox)
  }

  /**
   * Remove hidden checkbox for a label
   *
   * @param {string} labelId - Label ID to remove checkbox for
   */
  removeHiddenCheckbox(labelId) {
    const checkbox = this.hiddenInputsTarget.querySelector(
      `input[data-label-id="${labelId}"]`
    )

    if (checkbox) {
      checkbox.remove()
    }
  }

  /**
   * Update empty message visibility
   * Shows message if no labels selected, hides otherwise
   */
  updateEmptyMessage() {
    if (!this.hasEmptyMessageTarget) return

    const hasSelectedLabels = this.selectedLabels.size > 0

    if (hasSelectedLabels) {
      this.emptyMessageTarget.classList.add("hidden")
    } else {
      this.emptyMessageTarget.classList.remove("hidden")
    }
  }

  /**
   * Show empty state for no search results
   */
  showEmptyState() {
    if (this.hasEmptyStateTarget && this.hasLabelListTarget) {
      this.labelListTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
    }
  }

  /**
   * Hide empty state
   */
  hideEmptyState() {
    if (this.hasEmptyStateTarget && this.hasLabelListTarget) {
      this.labelListTarget.classList.remove("hidden")
      this.emptyStateTarget.classList.add("hidden")
    }
  }

  /**
   * Announce message to screen readers
   * Creates a live region for accessibility
   *
   * @param {string} message - Message to announce
   */
  announceToScreenReader(message) {
    const announcement = document.createElement("div")
    announcement.setAttribute("role", "status")
    announcement.setAttribute("aria-live", "polite")
    announcement.className = "sr-only"
    announcement.textContent = message

    document.body.appendChild(announcement)

    // Remove after announcement
    setTimeout(() => {
      announcement.remove()
    }, 1000)
  }

  /**
   * Escape HTML to prevent XSS
   *
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Clean up when controller disconnects
   */
  disconnect() {
    // Clear selected labels set
    this.selectedLabels.clear()
  }
}
