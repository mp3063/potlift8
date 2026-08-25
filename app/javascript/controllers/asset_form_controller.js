import { Controller } from "@hotwired/stimulus"

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
    this.updateFields()
  }

  updateFields() {
    const selectedType = this.typeSelectTarget.value

    this.hideAllFields()

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

  showDocumentFields() {
    if (this.hasDocumentFieldsTarget) {
      this.documentFieldsTarget.classList.remove("hidden")
    }
  }

  showVideoFields() {
    if (this.hasVideoFieldsTarget) {
      this.videoFieldsTarget.classList.remove("hidden")
    }
  }

  showLinkFields() {
    if (this.hasLinkFieldsTarget) {
      this.linkFieldsTarget.classList.remove("hidden")
    }
  }

  clearDocumentFields() {
    if (this.hasDocumentFileTarget) {
      this.documentFileTarget.value = ""
    }
  }

  clearVideoFields() {
    if (this.hasVideoUrlTarget) {
      this.videoUrlTarget.value = ""
    }
    if (this.hasVideoFileTarget) {
      this.videoFileTarget.value = ""
    }
  }

  clearLinkFields() {
    if (this.hasLinkUrlTarget) {
      this.linkUrlTarget.value = ""
    }
  }
}
