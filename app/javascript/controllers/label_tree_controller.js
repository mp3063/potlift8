import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

/**
 * Label Tree Controller
 *
 * Handles hierarchical label tree with drag-and-drop functionality:
 * - Drag-and-drop reordering of labels using SortableJS
 * - Expand/collapse sublabels with animated icons
 * - Persist expanded state to localStorage
 * - Send reorder requests to server with new parent_id and position
 * - Full keyboard accessibility (Enter/Space to toggle)
 *
 * Expected DOM structure:
 *   <div data-controller="label-tree">
 *     <ul data-label-tree-target="list">
 *       <li data-label-id="1">
 *         <div>
 *           <button data-action="click->label-tree#toggle keydown.enter->label-tree#toggle keydown.space->label-tree#toggle">
 *             <svg data-label-tree-target="icon">...</svg>
 *           </button>
 *           <span>Label Name</span>
 *         </div>
 *         <ul data-label-tree-target="list" class="hidden">
 *           <!-- sublabels -->
 *         </ul>
 *       </li>
 *     </ul>
 *   </div>
 *
 * @example localStorage structure for expanded state
 *   {
 *     "label_tree_expanded": ["1", "5", "12"]  // Array of expanded label IDs
 *   }
 */
export default class extends Controller {
  static targets = ["list", "icon"]
  static values = {
    reorderUrl: { type: String, default: "/labels/reorder" }
  }

  /**
   * Initialize controller:
   * - Set up SortableJS on all lists
   * - Load expanded state from localStorage
   */
  connect() {
    this.initSortable()
    this.loadExpandedState()
  }

  /**
   * Clean up SortableJS instances on disconnect
   */
  disconnect() {
    this.sortableInstances?.forEach(instance => instance.destroy())
    this.sortableInstances = []
  }

  /**
   * Initialize SortableJS on all list targets
   *
   * Features:
   * - Shared group allows dragging between levels
   * - Animation for smooth transitions
   * - Fallback ensures proper positioning
   * - Swap threshold for better UX
   */
  initSortable() {
    this.sortableInstances = []

    this.listTargets.forEach(list => {
      const sortable = Sortable.create(list, {
        group: 'labels',
        animation: 150,
        fallbackOnBody: true,
        swapThreshold: 0.65,
        handle: '.drag-handle', // Optional: add handle class to drag icon
        ghostClass: 'opacity-50',
        dragClass: 'bg-blue-50',
        onEnd: (event) => {
          this.handleDrop(event)
        }
      })

      this.sortableInstances.push(sortable)
    })
  }

  /**
   * Toggle expand/collapse for a label's sublabels
   *
   * Features:
   * - Toggle hidden class on children list
   * - Rotate icon 90deg (collapsed → expanded)
   * - Persist state to localStorage
   * - Keyboard accessible (Enter/Space)
   *
   * @param {Event} event - Click or keydown event
   */
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Handle keyboard events
    if (event.type === 'keydown') {
      // Only proceed for Enter or Space
      if (event.key !== 'Enter' && event.key !== ' ') {
        return
      }
      event.preventDefault() // Prevent space from scrolling
    }

    const button = event.currentTarget
    const listItem = button.closest('li[data-label-id]')
    const labelId = listItem.dataset.labelId
    const childList = listItem.querySelector(':scope > ul')
    const icon = button.querySelector('[data-label-tree-target="icon"]')

    if (!childList) return // No children to toggle

    // Toggle visibility
    const isExpanded = !childList.classList.contains('hidden')

    if (isExpanded) {
      // Collapse
      childList.classList.add('hidden')
      icon?.classList.remove('rotate-90')
      icon?.classList.add('rotate-0')
      button.setAttribute('aria-expanded', 'false')
      this.saveExpandedState(labelId, false)
    } else {
      // Expand
      childList.classList.remove('hidden')
      icon?.classList.remove('rotate-0')
      icon?.classList.add('rotate-90')
      button.setAttribute('aria-expanded', 'true')
      this.saveExpandedState(labelId, true)
    }
  }

  /**
   * Handle drop event from SortableJS
   *
   * Process:
   * 1. Collect all sibling label IDs in new order
   * 2. Determine new parent_id (from parent <li> or null for root)
   * 3. Send PATCH request to /labels/reorder
   * 4. Handle errors gracefully
   *
   * Request payload:
   *   {
   *     label_id: "5",
   *     parent_id: "2" or null,
   *     position: 0,
   *     sibling_ids: ["5", "7", "3"]
   *   }
   *
   * @param {Event} event - SortableJS onEnd event
   */
  async handleDrop(event) {
    const draggedItem = event.item
    const labelId = draggedItem.dataset.labelId
    const newParentList = event.to
    const position = event.newIndex

    // Determine new parent_id
    let parentId = null
    const parentItem = newParentList.closest('li[data-label-id]')
    if (parentItem) {
      parentId = parentItem.dataset.labelId
    }

    // Collect sibling IDs in new order
    const siblingItems = newParentList.querySelectorAll(':scope > li[data-label-id]')
    const siblingIds = Array.from(siblingItems).map(item => item.dataset.labelId)

    // Prepare request payload
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

        // Revert the DOM change on error
        // SortableJS doesn't provide easy revert, so we might need to reload
        // For now, just log the error
      } else {
        // Success - optionally show success message
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

  /**
   * Save expanded state for a label to localStorage
   *
   * @param {string} labelId - Label ID
   * @param {boolean} expanded - Whether label is expanded
   */
  saveExpandedState(labelId, expanded) {
    try {
      const key = 'label_tree_expanded'
      const stored = localStorage.getItem(key)
      let expandedIds = stored ? JSON.parse(stored) : []

      if (expanded) {
        // Add to array if not present
        if (!expandedIds.includes(labelId)) {
          expandedIds.push(labelId)
        }
      } else {
        // Remove from array
        expandedIds = expandedIds.filter(id => id !== labelId)
      }

      localStorage.setItem(key, JSON.stringify(expandedIds))
    } catch (error) {
      // localStorage might be disabled or full
      console.warn('Could not save expanded state:', error)
    }
  }

  /**
   * Load expanded state from localStorage on page load
   *
   * Restores expanded/collapsed state for all labels
   */
  loadExpandedState() {
    try {
      const key = 'label_tree_expanded'
      const stored = localStorage.getItem(key)
      const expandedIds = stored ? JSON.parse(stored) : []

      expandedIds.forEach(labelId => {
        const listItem = this.element.querySelector(`li[data-label-id="${labelId}"]`)
        if (!listItem) return

        const childList = listItem.querySelector(':scope > ul')
        const button = listItem.querySelector('button[data-action*="label-tree#toggle"]')
        const icon = button?.querySelector('[data-label-tree-target="icon"]')

        if (childList) {
          childList.classList.remove('hidden')
          icon?.classList.remove('rotate-0')
          icon?.classList.add('rotate-90')
          button?.setAttribute('aria-expanded', 'true')
        }
      })
    } catch (error) {
      // localStorage might be disabled
      console.warn('Could not load expanded state:', error)
    }
  }

  /**
   * Get CSRF token from meta tag
   *
   * @returns {string} CSRF token
   */
  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }

  /**
   * Show error notification
   * Uses flash component if available, otherwise logs to console
   *
   * @param {string} message - Error message
   */
  showError(message) {
    // Try to use flash component
    const flashContainer = document.querySelector('[data-controller="flash"]')
    if (flashContainer) {
      // Dispatch custom event that flash controller can listen to
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

  /**
   * Show success notification
   * Uses flash component if available
   *
   * @param {string} message - Success message
   */
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
