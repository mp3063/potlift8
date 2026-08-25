import { Controller } from "@hotwired/stimulus"

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

  connect() {
    // Track selected label IDs to prevent duplicates
    this.selectedLabels = new Set()

    this.initializeSelectedLabels()

    console.log("Label form selector controller connected")
  }

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

  filterLabels(event) {
    const searchTerm = event.target.value.toLowerCase().trim()
    let visibleCount = 0

    this.labelOptionTargets.forEach(option => {
      const labelName = option.dataset.labelName?.toLowerCase() || ''
      const labelCode = option.dataset.labelCode?.toLowerCase() || ''
      const matches = labelName.includes(searchTerm) || labelCode.includes(searchTerm)

      if (matches) {
        option.classList.remove("hidden")
        visibleCount++
      } else {
        option.classList.add("hidden")
      }
    })

    if (visibleCount === 0 && searchTerm !== "") {
      this.showEmptyState()
    } else {
      this.hideEmptyState()
    }
  }

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

    this.selectedLabels.add(labelId)

    this.createLabelTag(labelId, labelName, labelColor)

    this.createHiddenCheckbox(labelId)

    this.updateEmptyMessage()

    // Announce to screen readers
    this.announceToScreenReader(`Label ${labelName} added`)

    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.searchTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    button.disabled = true
    button.classList.add("opacity-50", "cursor-not-allowed")
    button.setAttribute("aria-disabled", "true")
  }

  removeLabel(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const labelId = button.dataset.labelId
    const tagElement = button.parentElement

    if (!tagElement) {
      console.error("Could not find label tag element")
      return
    }

    const labelNameSpan = tagElement.querySelector("span.font-medium")
    const labelName = labelNameSpan ? labelNameSpan.textContent.trim() : "Unknown"

    this.selectedLabels.delete(labelId)

    tagElement.style.transition = "opacity 150ms ease-out, transform 150ms ease-out"
    tagElement.style.opacity = "0"
    tagElement.style.transform = "scale(0.9)"

    setTimeout(() => {
      tagElement.remove()

      this.updateEmptyMessage()

      // Announce to screen readers
      this.announceToScreenReader(`Label ${labelName} removed`)
    }, 150)

    this.removeHiddenCheckbox(labelId)

    const availableButton = Array.from(this.labelOptionTargets).find(
      btn => btn.dataset.labelId === labelId
    )

    if (availableButton) {
      availableButton.disabled = false
      availableButton.classList.remove("opacity-50", "cursor-not-allowed")
      availableButton.removeAttribute("aria-disabled")
    }
  }

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

    requestAnimationFrame(() => {
      tag.style.opacity = "1"
      tag.style.transform = "scale(1)"
    })
  }

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

  showEmptyState() {
    if (this.hasEmptyStateTarget && this.hasLabelListTarget) {
      this.labelListTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
    }
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget && this.hasLabelListTarget) {
      this.labelListTarget.classList.remove("hidden")
      this.emptyStateTarget.classList.add("hidden")
    }
  }

  announceToScreenReader(message) {
    const announcement = document.createElement("div")
    announcement.setAttribute("role", "status")
    announcement.setAttribute("aria-live", "polite")
    announcement.className = "sr-only"
    announcement.textContent = message

    document.body.appendChild(announcement)

    setTimeout(() => {
      announcement.remove()
    }, 1000)
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  disconnect() {
    this.selectedLabels.clear()
  }
}
