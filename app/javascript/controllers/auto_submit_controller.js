import { Controller } from "@hotwired/stimulus"

/**
 * Auto Submit Controller
 *
 * Automatically submits a form when an input changes.
 * Can be used on form elements like selects to trigger form submission.
 *
 * Usage:
 *   <form data-controller="auto-submit">
 *     <select data-action="change->auto-submit#submit">
 *       ...
 *     </select>
 *   </form>
 *
 * Or on individual elements:
 *   <select data-controller="auto-submit" data-action="change->auto-submit#submit">
 */
export default class extends Controller {
  submit() {
    // Find the closest form and submit it
    const form = this.element.closest('form')
    if (form) {
      form.requestSubmit()
    }
  }
}
