import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "icon"]
  static values = {
    reorderUrl: { type: String, default: "/labels/reorder" }
  }

  connect() {
    this.loadExpandedState()
  }

  disconnect() {
    this.sortableInstances?.forEach(instance => instance.destroy())
    this.sortableInstances = []
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (event.type === 'keydown') {
      if (event.key !== 'Enter' && event.key !== ' ') {
        return
      }
      event.preventDefault() // Prevent space from scrolling
    }

    const button = event.currentTarget
    const container = button.closest('[data-label-id]')
    const labelId = container?.dataset.labelId

    let childList = container?.querySelector(`#sublabels-${labelId}`)
    if (!childList) {
      childList = document.querySelector(`#sublabels-${labelId}`)
    }
    const icon = button.querySelector('[data-label-tree-target="icon"]')

    if (!childList) {
      return
    }

    const isExpanded = !childList.classList.contains('hidden')

    if (isExpanded) {
      childList.classList.add('hidden')
      icon?.classList.remove('rotate-90')
      icon?.classList.add('rotate-0')
      button.setAttribute('aria-expanded', 'false')
      this.saveExpandedState(labelId, false)
    } else {
      childList.classList.remove('hidden')
      icon?.classList.remove('rotate-0')
      icon?.classList.add('rotate-90')
      button.setAttribute('aria-expanded', 'true')
      this.saveExpandedState(labelId, true)
    }
  }

  async handleDrop(event) {
    const draggedItem = event.item
    const labelId = draggedItem.dataset.labelId
    const newParentList = event.to
    const position = event.newIndex

    let parentId = null
    const parentItem = newParentList.closest('li[data-label-id]')
    if (parentItem) {
      parentId = parentItem.dataset.labelId
    }

    const siblingItems = newParentList.querySelectorAll(':scope > li[data-label-id]')
    const siblingIds = Array.from(siblingItems).map(item => item.dataset.labelId)

    const payload = {
      label_id: labelId,
      parent_id: parentId,
      position: position,
      sibling_ids: siblingIds
    }

    try {
      const response = await fetch(this.reorderUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        console.error('Label reorder failed:', response.statusText, errorData)
        this.showError('Failed to reorder label. Please refresh the page.')

      } else {
        const data = await response.json().catch(() => ({}))
        if (data.message) {
          this.showSuccess(data.message)
        }
      }
    } catch (error) {
      console.error('Network error during label reorder:', error)
      this.showError('Network error. Please check your connection and try again.')
    }
  }

  saveExpandedState(labelId, expanded) {
    try {
      const key = 'label_tree_expanded'
      const stored = localStorage.getItem(key)
      let expandedIds = stored ? JSON.parse(stored) : []

      if (expanded) {
        if (!expandedIds.includes(labelId)) {
          expandedIds.push(labelId)
        }
      } else {
        expandedIds = expandedIds.filter(id => id !== labelId)
      }

      localStorage.setItem(key, JSON.stringify(expandedIds))
    } catch (error) {
      console.warn('Could not save expanded state:', error)
    }
  }

  loadExpandedState() {
    try {
      const key = 'label_tree_expanded'
      const stored = localStorage.getItem(key)
      const expandedIds = stored ? JSON.parse(stored) : []

      expandedIds.forEach(labelId => {
        const container = this.element.querySelector(`[data-label-id="${labelId}"]`)
        if (!container) return

        const childList = container.querySelector(`#sublabels-${labelId}`)
        const button = container.querySelector('button[data-action*="label-tree#toggle"]')
        const icon = button?.querySelector('[data-label-tree-target="icon"]')

        if (childList) {
          childList.classList.remove('hidden')
          icon?.classList.remove('rotate-0')
          icon?.classList.add('rotate-90')
          button?.setAttribute('aria-expanded', 'true')
        }
      })
    } catch (error) {
      console.warn('Could not load expanded state:', error)
    }
  }

  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }

  /**
   * Show error notification
   * Uses flash component if available, otherwise logs to console
   */
  showError(message) {
    const flashContainer = document.querySelector('[data-controller="flash"]')
    if (flashContainer) {
      const event = new CustomEvent('flash:show', {
        detail: { type: 'error', message: message }
      })
      window.dispatchEvent(event)
    } else {
      // Fallback: log to console
      console.error(message)
      alert(message) // Simple fallback for user notification
    }
  }

  showSuccess(message) {
    const flashContainer = document.querySelector('[data-controller="flash"]')
    if (flashContainer) {
      const event = new CustomEvent('flash:show', {
        detail: { type: 'success', message: message }
      })
      window.dispatchEvent(event)
    }
  }
}
