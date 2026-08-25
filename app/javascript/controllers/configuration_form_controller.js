import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.valueCount = this.containerTarget.querySelectorAll('[data-value-field]').length
  }

  addValue(event) {
    event.preventDefault()

    const template = this.templateTarget.content.cloneNode(true)
    const newField = template.querySelector('[data-value-field]')

    this.updateFieldIdentifiers(newField, this.valueCount)

    this.containerTarget.appendChild(template)

    const input = newField.querySelector('input[type="text"]')
    if (input) {
      setTimeout(() => input.focus(), 10)
    }

    // Announce to screen readers
    this.announceFieldAdded()

    this.valueCount++
  }

  removeValue(event) {
    event.preventDefault()

    const field = event.currentTarget.closest('[data-value-field]')
    if (!field) return

    const valueId = field.dataset.valueId

    if (valueId && valueId !== 'new') {
      const destroyInput = field.querySelector('input[name*="[_destroy]"]')
      if (destroyInput) {
        destroyInput.value = '1'
        field.style.display = 'none'
      } else {
        field.remove()
      }
    } else {
      field.remove()
    }

    // Announce to screen readers
    this.announceFieldRemoved()

    this.focusNextInput()
  }

  updateFieldIdentifiers(field, index) {
    const inputs = field.querySelectorAll('input, select, textarea')

    inputs.forEach(input => {
      if (input.name) {
        input.name = input.name.replace(/\[new_record\]/, `[${index}]`)
      }

      if (input.id) {
        input.id = input.id.replace(/_new_record_/, `_${index}_`)
      }
    })

    const labels = field.querySelectorAll('label')
    labels.forEach(label => {
      if (label.htmlFor) {
        label.htmlFor = label.htmlFor.replace(/_new_record_/, `_${index}_`)
      }
    })

    field.dataset.valueId = 'new'
  }

  focusNextInput() {
    const visibleFields = Array.from(this.containerTarget.querySelectorAll('[data-value-field]'))
      .filter(field => field.style.display !== 'none')

    if (visibleFields.length > 0) {
      const input = visibleFields[visibleFields.length - 1].querySelector('input[type="text"]')
      if (input) input.focus()
    }
  }

  announceFieldAdded() {
    this.announce("Configuration value field added")
  }

  announceFieldRemoved() {
    this.announce("Configuration value field removed")
  }

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
