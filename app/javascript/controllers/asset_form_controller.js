import { Controller } from "@hotwired/stimulus"

/**
 * Asset Form Controller
 *
 * Handles dynamic form field visibility based on selected asset type.
 *
 * Usage:
 * <form data-controller="asset-form">
 *   <select data-action="change->asset-form#updateFields" data-asset-form-target="typeSelect">
 *   <div data-asset-form-target="documentFields">Document fields</div>
 *   <div data-asset-form-target="videoFields">Video fields</div>
 *   <div data-asset-form-target="linkFields">Link fields</div>
 * </form>
 */
export default class extends Controller {
  static targets = [
    "typeSelect",
    "documentFields",
    "videoFields",
    "linkFields",
    "documentFile",
    "videoUrl",
    "videoFile",
    "linkUrl",
    "position"
  ]

  connect() {
    // Initialize field visibility based on current selection
    this.updateFields()
  }

  /**
   * Update field visibility based on selected asset type
   */
  updateFields() {
    const selectedType = this.typeSelectTarget.value

    // Hide all type-specific fields first
    this.hideAllFields()

    // Show appropriate fields based on selection
    switch (selectedType) {
      case "document":
        this.showDocumentFields()
        break
      case "video":
        this.showVideoFields()
        break
      case "link":
        this.showLinkFields()
        break
    }
  }

  /**
   * Hide all type-specific field groups
   */
  hideAllFields() {
    if (this.hasDocumentFieldsTarget) {
      this.documentFieldsTarget.classList.add("hidden")
      this.clearDocumentFields()
    }
    if (this.hasVideoFieldsTarget) {
      this.videoFieldsTarget.classList.add("hidden")
      this.clearVideoFields()
    }
    if (this.hasLinkFieldsTarget) {
      this.linkFieldsTarget.classList.add("hidden")
      this.clearLinkFields()
    }
  }

  /**
   * Show document upload fields
   */
  showDocumentFields() {
    if (this.hasDocumentFieldsTarget) {
      this.documentFieldsTarget.classList.remove("hidden")
    }
  }

  /**
   * Show video fields (URL and file upload)
   */
  showVideoFields() {
    if (this.hasVideoFieldsTarget) {
      this.videoFieldsTarget.classList.remove("hidden")
    }
  }

  /**
   * Show link fields
   */
  showLinkFields() {
    if (this.hasLinkFieldsTarget) {
      this.linkFieldsTarget.classList.remove("hidden")
    }
  }

  /**
   * Clear document fields when hidden
   */
  clearDocumentFields() {
    if (this.hasDocumentFileTarget) {
      this.documentFileTarget.value = ""
    }
  }

  /**
   * Clear video fields when hidden
   */
  clearVideoFields() {
    if (this.hasVideoUrlTarget) {
      this.videoUrlTarget.value = ""
    }
    if (this.hasVideoFileTarget) {
      this.videoFileTarget.value = ""
    }
  }

  /**
   * Clear link fields when hidden
   */
  clearLinkFields() {
    if (this.hasLinkUrlTarget) {
      this.linkUrlTarget.value = ""
    }
  }
}
