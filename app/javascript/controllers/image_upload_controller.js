import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["input", "dropzone", "progressContainer"]

  static values = {
    maxFileSize: { type: Number, default: 10 * 1024 * 1024 },
    acceptedTypes: { type: Array, default: ["image/jpeg", "image/png", "image/gif", "image/webp"] }
  }

  handleFiles(event) {
    const files = Array.from(event.target.files)
    this.uploadFiles(files)

    event.target.value = ""
  }

  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()

    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.setAttribute("aria-dropeffect", "none")

    const files = Array.from(event.dataTransfer.files).filter(file =>
      file.type.startsWith("image/")
    )

    if (files.length === 0) {
      this.showError("Please drop image files only (PNG, JPG, GIF, WebP)")
      return
    }

    this.uploadFiles(files)
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()

    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.setAttribute("aria-dropeffect", "copy")
  }

  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
      this.dropzoneTarget.setAttribute("aria-dropeffect", "none")
    }
  }

  uploadFiles(files) {
    files.forEach(file => {
      if (!this.isValidFileType(file)) {
        this.showError(`${file.name} is not a valid image type. Please use PNG, JPG, GIF, or WebP.`)
        return
      }

      if (!this.isValidFileSize(file)) {
        this.showError(`${file.name} exceeds the maximum file size of ${this.formatFileSize(this.maxFileSizeValue)}.`)
        return
      }

      this.uploadFile(file)
    })
  }

  uploadFile(file) {
    const progressBar = this.createProgressBar(file.name)
    const directUploadUrl = "/rails/active_storage/direct_uploads"

    const upload = new DirectUpload(file, directUploadUrl, {
      directUploadWillStoreFileWithXHR: (xhr) => {
        xhr.upload.addEventListener("progress", (event) => {
          const progress = (event.loaded / event.total) * 100
          this.updateProgressBar(progressBar, progress)
        })
      }
    })

    upload.create((error, blob) => {
      if (error) {
        this.handleUploadError(progressBar, error, file.name)
      } else {
        this.attachBlobToProduct(progressBar, blob)
      }
    })
  }

  createProgressBar(filename) {
    const container = document.createElement("div")
    container.className = "space-y-1"
    container.setAttribute("role", "status")
    container.setAttribute("aria-live", "polite")
    container.innerHTML = `
      <div class="flex justify-between text-sm">
        <span class="font-medium text-gray-700">${this.escapeHtml(filename)}</span>
        <span class="text-gray-500">0%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
      </div>
    `

    this.progressContainerTarget.appendChild(container)
    return container
  }

  updateProgressBar(container, progress) {
    const percentage = Math.round(progress)
    const progressBar = container.querySelector("div > div")
    const progressText = container.querySelector("span:last-child")

    progressBar.style.width = `${percentage}%`
    progressText.textContent = `${percentage}%`

    // Update aria-label for screen readers
    container.setAttribute("aria-label", `Upload progress: ${percentage}%`)
  }

  attachBlobToProduct(container, blob) {
    const formAction = this.element.action
    const csrfToken = document.querySelector("[name='csrf-token']").content

    fetch(formAction, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        signed_blob_id: blob.signed_id
      })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(() => {
      this.handleUploadSuccess(container)
    })
    .catch(error => {
      console.error("Error attaching blob:", error)
      this.handleUploadError(container, error, "Unknown file")
    })
  }

  handleUploadSuccess(container) {
    this.updateProgressBar(container, 100)

    const progressBar = container.querySelector("div > div")
    progressBar.classList.add("bg-green-600")

    // Announce success to screen readers
    container.setAttribute("aria-label", "Upload complete")

    setTimeout(() => {
      container.remove()

      if (this.progressContainerTarget.children.length === 0) {
        window.location.reload()
      }
    }, 500)
  }

  handleUploadError(container, error, filename) {
    container.classList.add("bg-red-50", "p-2", "rounded-md")

    const progressBar = container.querySelector("div > div")
    progressBar.classList.remove("bg-blue-600")
    progressBar.classList.add("bg-red-600")

    const progressText = container.querySelector("span:last-child")
    progressText.textContent = "Failed"
    progressText.classList.add("text-red-600")

    // Announce error to screen readers
    container.setAttribute("aria-label", `Upload failed: ${filename}`)
    container.setAttribute("role", "alert")

    console.error("Upload error:", error)
    this.showError(`Failed to upload ${filename}. Please try again.`)

    setTimeout(() => {
      container.remove()
    }, 5000)
  }

  isValidFileType(file) {
    return file.type.startsWith("image/")
  }

  isValidFileSize(file) {
    return file.size <= this.maxFileSizeValue
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"

    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))

    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i]
  }

  showError(message) {
    const errorDiv = document.createElement("div")
    errorDiv.className = "fixed top-20 right-4 z-50 max-w-sm rounded-md bg-red-50 p-4 shadow-lg"
    errorDiv.setAttribute("role", "alert")
    errorDiv.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium text-red-800">${this.escapeHtml(message)}</p>
        </div>
        <div class="ml-auto pl-3">
          <button type="button" class="inline-flex rounded-md bg-red-50 p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50">
            <span class="sr-only">Dismiss</span>
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
      </div>
    `

    document.body.appendChild(errorDiv)

    const dismissButton = errorDiv.querySelector("button")
    dismissButton.addEventListener("click", () => {
      errorDiv.remove()
    })

    setTimeout(() => {
      errorDiv.remove()
    }, 5000)
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
