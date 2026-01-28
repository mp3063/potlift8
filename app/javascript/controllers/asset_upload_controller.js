import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

/**
 * Asset Upload Controller
 *
 * Handles file uploads for product assets (documents, videos, PDFs, etc.)
 * with drag-and-drop support and progress tracking.
 * Uses ActiveStorage Direct Upload for efficient file uploads.
 *
 * Features:
 * - File input change handling
 * - Drag-and-drop support with visual feedback
 * - File type validation (configurable)
 * - File size validation (configurable, default 50MB)
 * - Upload progress bars
 * - Error handling with user feedback
 * - Blue-500 border on dragover (matches design system)
 * - Multiple file uploads
 * - ARIA live regions for screen reader feedback
 *
 * Targets:
 * - input: File input element
 * - dropzone: Drop zone container
 * - progressContainer: Container for progress bars
 * - errorContainer: Container for error messages
 *
 * Values:
 * - maxFileSize: Maximum file size in bytes (default: 50MB)
 * - acceptedTypes: Array of accepted MIME types
 * - acceptedExtensions: Array of accepted file extensions
 *
 * @example
 *   <form data-controller="asset-upload"
 *         data-asset-upload-max-file-size-value="52428800"
 *         data-asset-upload-accepted-types-value='["application/pdf", "application/msword"]'
 *         data-turbo="false">
 *     <div data-asset-upload-target="dropzone"
 *          data-action="drop->asset-upload#handleDrop
 *                       dragover->asset-upload#handleDragOver
 *                       dragleave->asset-upload#handleDragLeave">
 *       <input type="file"
 *              multiple
 *              data-asset-upload-target="input"
 *              data-action="change->asset-upload#handleFiles">
 *     </div>
 *     <div data-asset-upload-target="progressContainer"></div>
 *     <div data-asset-upload-target="errorContainer"></div>
 *   </form>
 */
export default class extends Controller {
  static targets = ["input", "dropzone", "progressContainer", "errorContainer"]

  static values = {
    maxFileSize: { type: Number, default: 50 * 1024 * 1024 }, // 50MB default
    acceptedTypes: { type: Array, default: [] }, // Empty = accept all
    acceptedExtensions: { type: Array, default: [] } // Empty = accept all
  }

  /**
   * Handle file input change event
   * Validates and uploads selected files
   *
   * @param {Event} event - Change event from file input
   */
  handleFiles(event) {
    const files = Array.from(event.target.files)
    this.uploadFiles(files)

    // Reset input so the same file can be selected again if needed
    event.target.value = ""
  }

  /**
   * Handle drop event
   * Validates and uploads dropped files
   *
   * @param {DragEvent} event - Drop event
   */
  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()

    // Remove dragover styles
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.setAttribute("aria-dropeffect", "none")

    // Get files from dataTransfer
    const files = Array.from(event.dataTransfer.files)

    if (files.length === 0) {
      this.showError("No files detected. Please try again.")
      return
    }

    this.uploadFiles(files)
  }

  /**
   * Handle dragover event
   * Adds visual feedback when files are dragged over dropzone
   *
   * @param {DragEvent} event - Dragover event
   */
  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()

    // Add visual feedback using blue to match design system
    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.setAttribute("aria-dropeffect", "copy")
  }

  /**
   * Handle dragleave event
   * Removes visual feedback when files leave dropzone
   *
   * @param {DragEvent} event - Dragleave event
   */
  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()

    // Only remove styles if we're actually leaving the dropzone
    // (not just moving to a child element)
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
      this.dropzoneTarget.setAttribute("aria-dropeffect", "none")
    }
  }

  /**
   * Upload multiple files
   * Validates each file before uploading
   *
   * @param {File[]} files - Array of files to upload
   */
  uploadFiles(files) {
    files.forEach(file => {
      // Validate file type
      if (!this.isValidFileType(file)) {
        const acceptedTypes = this.getAcceptedTypesMessage()
        this.showError(`${file.name} is not a valid file type. ${acceptedTypes}`)
        return
      }

      // Validate file size
      if (!this.isValidFileSize(file)) {
        this.showError(`${file.name} exceeds the maximum file size of ${this.formatFileSize(this.maxFileSizeValue)}.`)
        return
      }

      this.uploadFile(file)
    })
  }

  /**
   * Upload a single file using ActiveStorage Direct Upload
   * Creates progress bar and handles upload lifecycle
   *
   * @param {File} file - File to upload
   */
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

  /**
   * Create a progress bar element
   *
   * @param {string} filename - Name of file being uploaded
   * @returns {HTMLElement} Progress bar container element
   */
  createProgressBar(filename) {
    const container = document.createElement("div")
    container.className = "space-y-1 mb-3"
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

  /**
   * Update progress bar to show current upload progress
   *
   * @param {HTMLElement} container - Progress bar container
   * @param {number} progress - Upload progress (0-100)
   */
  updateProgressBar(container, progress) {
    const percentage = Math.round(progress)
    const progressBar = container.querySelector("div > div")
    const progressText = container.querySelector("span:last-child")

    progressBar.style.width = `${percentage}%`
    progressText.textContent = `${percentage}%`

    // Update aria-label for screen readers
    container.setAttribute("aria-label", `Upload progress: ${percentage}%`)
  }

  /**
   * Attach uploaded blob to product
   * POSTs signed blob ID to product assets controller
   *
   * @param {HTMLElement} container - Progress bar container
   * @param {Object} blob - ActiveStorage blob object with signed_id
   */
  attachBlobToProduct(container, blob) {
    // Find or create a hidden input for the signed blob ID
    let hiddenInput = this.element.querySelector('input[name="product_asset[signed_blob_id]"]')
    if (!hiddenInput) {
      hiddenInput = document.createElement("input")
      hiddenInput.type = "hidden"
      hiddenInput.name = "product_asset[signed_blob_id]"
      this.element.appendChild(hiddenInput)
    }
    hiddenInput.value = blob.signed_id

    this.handleUploadSuccess(container, blob)
  }

  /**
   * Handle successful upload
   * Replaces dropzone with file confirmation showing filename
   *
   * @param {HTMLElement} container - Progress bar container
   * @param {Object} blob - ActiveStorage blob object
   */
  handleUploadSuccess(container, blob) {
    // Set to 100% complete
    this.updateProgressBar(container, 100)

    // Update visual state
    const progressBar = container.querySelector("div > div")
    progressBar.classList.remove("bg-blue-600")
    progressBar.classList.add("bg-green-600")

    const progressText = container.querySelector("span:last-child")
    progressText.textContent = "Ready"
    progressText.classList.add("text-green-600")

    // Announce success to screen readers
    container.setAttribute("aria-label", "Upload complete — submit the form to save")

    // After a brief delay, replace the dropzone with a file confirmation
    setTimeout(() => {
      if (container.parentNode) {
        container.remove()
      }
      this.showFileConfirmation(blob)
    }, 1000)
  }

  /**
   * Show file confirmation in the dropzone after successful upload
   * Replaces the dropzone content with filename and success indicator
   *
   * @param {Object} blob - ActiveStorage blob object with filename
   */
  showFileConfirmation(blob) {
    // Find the visible dropzone (the one in the currently shown section)
    const dropzone = this.dropzoneTargets.find(dz => !dz.closest(".hidden"))
    if (!dropzone) return

    const filename = blob.filename || "Uploaded file"

    // Update dropzone styling
    dropzone.classList.remove("border-gray-300", "hover:border-gray-400")
    dropzone.classList.add("border-green-400", "bg-green-50")

    // Clear existing content
    while (dropzone.firstChild) {
      dropzone.removeChild(dropzone.firstChild)
    }

    // Build confirmation UI with safe DOM methods
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("class", "mx-auto h-10 w-10 text-green-500")
    svg.setAttribute("fill", "none")
    svg.setAttribute("viewBox", "0 0 24 24")
    svg.setAttribute("stroke-width", "1.5")
    svg.setAttribute("stroke", "currentColor")
    svg.setAttribute("aria-hidden", "true")
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("stroke-linecap", "round")
    path.setAttribute("stroke-linejoin", "round")
    path.setAttribute("d", "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
    svg.appendChild(path)

    const textContainer = document.createElement("div")
    textContainer.className = "mt-2"

    const filenameLine = document.createElement("p")
    filenameLine.className = "text-sm font-medium text-green-700"
    filenameLine.textContent = filename

    const hintLine = document.createElement("p")
    hintLine.className = "text-xs text-green-600 mt-1"
    hintLine.textContent = "File ready \u2014 click Upload to save"

    textContainer.appendChild(filenameLine)
    textContainer.appendChild(hintLine)

    dropzone.appendChild(svg)
    dropzone.appendChild(textContainer)
  }

  /**
   * Handle upload error
   * Shows error state in progress bar
   *
   * @param {HTMLElement} container - Progress bar container
   * @param {Error} error - Error object
   * @param {string} filename - Name of file that failed
   */
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

    // Remove error container after 5 seconds
    setTimeout(() => {
      container.remove()
    }, 5000)
  }

  /**
   * Validate file type
   *
   * @param {File} file - File to validate
   * @returns {boolean} True if file type is valid
   */
  isValidFileType(file) {
    // If no restrictions, accept all
    if (this.acceptedTypesValue.length === 0 && this.acceptedExtensionsValue.length === 0) {
      return true
    }

    // Check MIME type
    if (this.acceptedTypesValue.length > 0) {
      const isValidMimeType = this.acceptedTypesValue.some(type => {
        // Support wildcards like "video/*"
        if (type.endsWith("/*")) {
          const prefix = type.slice(0, -2)
          return file.type.startsWith(prefix)
        }
        return file.type === type
      })

      if (isValidMimeType) return true
    }

    // Check file extension
    if (this.acceptedExtensionsValue.length > 0) {
      const fileExtension = file.name.split(".").pop().toLowerCase()
      return this.acceptedExtensionsValue.includes(`.${fileExtension}`)
    }

    return false
  }

  /**
   * Validate file size
   *
   * @param {File} file - File to validate
   * @returns {boolean} True if file size is within limit
   */
  isValidFileSize(file) {
    return file.size <= this.maxFileSizeValue
  }

  /**
   * Get accepted types message for error display
   *
   * @returns {string} Human-readable accepted types message
   */
  getAcceptedTypesMessage() {
    if (this.acceptedExtensionsValue.length > 0) {
      return `Accepted formats: ${this.acceptedExtensionsValue.join(", ")}`
    }
    if (this.acceptedTypesValue.length > 0) {
      return `Accepted types: ${this.acceptedTypesValue.join(", ")}`
    }
    return ""
  }

  /**
   * Format file size for display
   *
   * @param {number} bytes - Size in bytes
   * @returns {string} Formatted size (e.g., "50 MB")
   */
  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"

    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))

    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i]
  }

  /**
   * Show error message to user
   * Creates a flash-style message at the top of the page
   *
   * @param {string} message - Error message to display
   */
  showError(message) {
    // If error container exists, use it
    if (this.hasErrorContainerTarget) {
      const errorDiv = document.createElement("div")
      errorDiv.className = "rounded-md bg-red-50 p-4 mb-4"
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
            <button type="button" class="inline-flex rounded-md bg-red-50 p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      this.errorContainerTarget.appendChild(errorDiv)

      // Add dismiss handler
      const dismissButton = errorDiv.querySelector("button")
      dismissButton.addEventListener("click", () => {
        errorDiv.remove()
      })

      // Auto-dismiss after 5 seconds
      setTimeout(() => {
        errorDiv.remove()
      }, 5000)
    } else {
      // Fallback to fixed position flash message
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
            <button type="button" class="inline-flex rounded-md bg-red-50 p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50" aria-label="Dismiss">
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      `

      document.body.appendChild(errorDiv)

      // Add dismiss handler
      const dismissButton = errorDiv.querySelector("button")
      dismissButton.addEventListener("click", () => {
        errorDiv.remove()
      })

      // Auto-dismiss after 5 seconds
      setTimeout(() => {
        errorDiv.remove()
      }, 5000)
    }
  }

  /**
   * Escape HTML to prevent XSS
   *
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
