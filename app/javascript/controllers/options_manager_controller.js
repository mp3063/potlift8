import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Options Manager Controller
 *
 * Manages select/multiselect options with drag-and-drop reordering:
 * - Add/remove options dynamically
 * - Drag-and-drop reordering with SortableJS
 * - Syncs to hidden field for form submission
 *
 * Values:
 *   options: Array - Initial options array
 *
 * Targets:
 *   container: Options list container
 *   hiddenField: Hidden field for form submission
 */
export default class extends Controller {
  static targets = ["container", "hiddenField"]
  static values = { options: Array }

  connect() {
    this.options = this.optionsValue || []
    this.render()
    this.initSortable()
  }

  /**
   * Initialize SortableJS for drag-and-drop
   */
  initSortable() {
    Sortable.create(this.containerTarget, {
      animation: 150,
      handle: ".option-handle",
      ghostClass: "bg-blue-50",
      dragClass: "opacity-50",
      onEnd: () => {
        this.updateOptionsFromDOM()
      }
    })
  }

  /**
   * Add a new empty option
   */
  addOption() {
    this.options.push("")
    this.render()

    // Focus the new input
    const inputs = this.containerTarget.querySelectorAll("input[type='text']")
    if (inputs.length > 0) {
      inputs[inputs.length - 1].focus()
    }
  }

  /**
   * Remove an option by index
   */
  removeOption(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.options.splice(index, 1)
    this.render()
  }

  /**
   * Update option value when input changes
   */
  updateOption(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.options[index] = event.currentTarget.value
    this.updateHiddenField()
  }

  /**
   * Update options array from DOM after drag-and-drop
   */
  updateOptionsFromDOM() {
    const inputs = this.containerTarget.querySelectorAll("input[type='text']")
    this.options = Array.from(inputs).map(input => input.value)
    this.updateHiddenField()
  }

  /**
   * Render options list
   */
  render() {
    this.containerTarget.innerHTML = this.options.map((option, index) => `
      <div class="flex items-center gap-x-2">
        <button type="button" class="option-handle cursor-move text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded" aria-label="Drag to reorder">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9h16.5m-16.5 6.75h16.5" />
          </svg>
        </button>
        <input
          type="text"
          value="${this.escapeHtml(option)}"
          data-index="${index}"
          data-action="input->options-manager#updateOption"
          class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          placeholder="Option ${index + 1}"
        >
        <button
          type="button"
          data-index="${index}"
          data-action="click->options-manager#removeOption"
          class="text-red-400 hover:text-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 rounded"
          aria-label="Remove option"
        >
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `).join('')

    this.updateHiddenField()
  }

  /**
   * Update hidden field with current options (as JSON array)
   */
  updateHiddenField() {
    // Filter out empty options
    const validOptions = this.options.filter(opt => opt.trim() !== '')
    this.hiddenFieldTarget.value = JSON.stringify(validOptions)
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
