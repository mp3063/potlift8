import { Controller } from "@hotwired/stimulus"

/**
 * Configuration Form Controller
 *
 * Manages dynamic configuration value fields in the configuration form.
 * Handles adding and removing configuration values (e.g., sizes, colors).
 *
 * Targets:
 *   - container: Container for configuration value fields
 *   - template: Hidden template for new configuration value fields
 *
 * Actions:
 *   - addValue: Add a new configuration value field
 *   - removeValue: Remove a configuration value field
 *
 * Usage:
 *   <div data-controller="configuration-form">
 *     <div data-configuration-form-target="container">
 *       <!-- Existing value fields -->
 *     </div>
 *     <template data-configuration-form-target="template">
 *       <!-- Value field template -->
 *     </template>
 *     <button data-action="click->configuration-form#addValue">Add Value</button>
 *   </div>
 *
 * Accessibility:
 * - Focus management (new field auto-focused)
 * - Keyboard support (Enter to add, with proper labels)
 * - Screen reader announcements
 */
export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.valueCount = this.containerTarget.querySelectorAll('[data-value-field]').length
  }

  /**
   * Add a new configuration value field
   *
   * @param {Event} event - Click event
   */
  addValue(event) {
    event.preventDefault()

    const template = this.templateTarget.content.cloneNode(true)
    const newField = template.querySelector('[data-value-field]')

    // Update field IDs and names with unique index
    this.updateFieldIdentifiers(newField, this.valueCount)

    // Append to container
    this.containerTarget.appendChild(template)

    // Focus new input
    const input = newField.querySelector('input[type="text"]')
    if (input) {
      setTimeout(() => input.focus(), 10)
    }

    // Announce to screen readers
    this.announceFieldAdded()

    this.valueCount++
  }

  /**
   * Remove a configuration value field
   *
   * @param {Event} event - Click event
   */
  removeValue(event) {
    event.preventDefault()

    const field = event.currentTarget.closest('[data-value-field]')
    if (!field) return

    const valueId = field.dataset.valueId

    // If existing record, mark for destruction
    if (valueId && valueId !== 'new') {
      const destroyInput = field.querySelector('input[name*="[_destroy]"]')
      if (destroyInput) {
        destroyInput.value = '1'
        field.style.display = 'none'
      } else {
        field.remove()
      }
    } else {
      // New record, just remove from DOM
      field.remove()
    }

    // Announce to screen readers
    this.announceFieldRemoved()

    // Focus next available input
    this.focusNextInput()
  }

  /**
   * Update field identifiers (IDs and names) with unique index
   *
   * @param {HTMLElement} field - The field to update
   * @param {Number} index - Unique index for this field
   */
  updateFieldIdentifiers(field, index) {
    const inputs = field.querySelectorAll('input, select, textarea')

    inputs.forEach(input => {
      // Update name attribute
      if (input.name) {
        input.name = input.name.replace(/\[new_record\]/, `[${index}]`)
      }

      // Update id attribute
      if (input.id) {
        input.id = input.id.replace(/_new_record_/, `_${index}_`)
      }
    })

    // Update labels
    const labels = field.querySelectorAll('label')
    labels.forEach(label => {
      if (label.htmlFor) {
        label.htmlFor = label.htmlFor.replace(/_new_record_/, `_${index}_`)
      }
    })

    // Mark as new
    field.dataset.valueId = 'new'
  }

  /**
   * Focus next available input after removal
   */
  focusNextInput() {
    const visibleFields = Array.from(this.containerTarget.querySelectorAll('[data-value-field]'))
      .filter(field => field.style.display !== 'none')

    if (visibleFields.length > 0) {
      const input = visibleFields[visibleFields.length - 1].querySelector('input[type="text"]')
      if (input) input.focus()
    }
  }

  /**
   * Announce field addition to screen readers
   */
  announceFieldAdded() {
    this.announce("Configuration value field added")
  }

  /**
   * Announce field removal to screen readers
   */
  announceFieldRemoved() {
    this.announce("Configuration value field removed")
  }

  /**
   * Announce message to screen readers
   *
   * @param {String} message - Message to announce
   */
  announce(message) {
    let liveRegion = document.getElementById("configuration-form-announcer")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "configuration-form-announcer"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.className = "sr-only"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = message
  }
}
