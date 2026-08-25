import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "urlInput",
    "preview",
    "errorMessage",
    "videoIdInput",
    "platformInput"
  ]

  static values = {
    currentUrl: String,
    currentPlatform: String,
    currentVideoId: String
  }

  get youtubePatterns() {
    return [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})/
    ]
  }

  get vimeoPatterns() {
    return [
      /vimeo\.com\/(\d+)/,
      /player\.vimeo\.com\/video\/(\d+)/
    ]
  }

  validateUrl(event) {
    const url = this.urlInputTarget.value.trim()

    if (!url) {
      this.clearPreview()
      this.clearError()
      return
    }

    const result = this.extractVideoInfo(url)

    if (result) {
      this.currentUrlValue = url
      this.currentPlatformValue = result.platform
      this.currentVideoIdValue = result.videoId

      if (this.hasVideoIdInputTarget) {
        this.videoIdInputTarget.value = result.videoId
      }
      if (this.hasPlatformInputTarget) {
        this.platformInputTarget.value = result.platform
      }

      this.showPreview(result.platform, result.videoId)
      this.clearError()
    } else {
      this.showError("Invalid video URL. Please enter a valid YouTube or Vimeo URL.")
      this.clearPreview()
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.innerHTML = ""
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  extractVideoInfo(url) {
    for (const pattern of this.youtubePatterns) {
      const match = url.match(pattern)
      if (match && match[1]) {
        return {
          platform: "youtube",
          videoId: match[1]
        }
      }
    }

    for (const pattern of this.vimeoPatterns) {
      const match = url.match(pattern)
      if (match && match[1]) {
        return {
          platform: "vimeo",
          videoId: match[1]
        }
      }
    }

    return null
  }

  showPreview(platform, videoId) {
    if (!this.hasPreviewTarget) return

    let thumbnailUrl
    let embedUrl
    let platformName

    if (platform === "youtube") {
      thumbnailUrl = `https://img.youtube.com/vi/${videoId}/mqdefault.jpg`
      embedUrl = `https://www.youtube.com/embed/${videoId}`
      platformName = "YouTube"
    } else if (platform === "vimeo") {
      thumbnailUrl = `https://vumbnail.com/${videoId}.jpg`
      embedUrl = `https://player.vimeo.com/video/${videoId}`
      platformName = "Vimeo"
    }

    this.previewTarget.innerHTML = `
      <div class="relative rounded-lg overflow-hidden border-2 border-gray-200 bg-gray-100" role="img" aria-label="${platformName} video preview">
        <div class="aspect-video relative">
          <img src="${thumbnailUrl}"
               alt="${platformName} video thumbnail"
               class="w-full h-full object-cover"
               onerror="this.src='data:image/svg+xml,%3Csvg xmlns=\\'http://www.w3.org/2000/svg\\' width=\\'320\\' height=\\'180\\' viewBox=\\'0 0 320 180\\'%3E%3Crect fill=\\'%23e5e7eb\\' width=\\'320\\' height=\\'180\\'/%3E%3Ctext fill=\\'%239ca3af\\' font-family=\\'sans-serif\\' font-size=\\'18\\' x=\\'50%25\\' y=\\'50%25\\' text-anchor=\\'middle\\' dy=\\'.3em\\'%3E${platformName} Video%3C/text%3E%3C/svg%3E'">
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="bg-black bg-opacity-70 rounded-full p-4">
              <svg class="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z" />
              </svg>
            </div>
          </div>
        </div>
        <div class="absolute top-2 right-2">
          <span class="inline-flex items-center rounded-md bg-${platform === 'youtube' ? 'red' : 'blue'}-600 px-2 py-1 text-xs font-medium text-white shadow-sm">
            ${platformName}
          </span>
        </div>
      </div>
      <p class="mt-2 text-sm text-gray-600" role="status" aria-live="polite">
        Preview loaded successfully
      </p>
    `

    this.previewTarget.classList.remove("hidden")
  }

  clearPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = ""
      this.previewTarget.classList.add("hidden")
    }

    if (this.hasVideoIdInputTarget) {
      this.videoIdInputTarget.value = ""
    }
    if (this.hasPlatformInputTarget) {
      this.platformInputTarget.value = ""
    }

    this.currentUrlValue = ""
    this.currentPlatformValue = ""
    this.currentVideoIdValue = ""
  }

  showError(message) {
    if (!this.hasErrorMessageTarget) return

    this.errorMessageTarget.innerHTML = `
      <div class="rounded-md bg-red-50 p-4" role="alert">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">Invalid Video URL</h3>
            <div class="mt-2 text-sm text-red-700">
              <p>${this.escapeHtml(message)}</p>
              <p class="mt-2">Supported formats:</p>
              <ul class="list-disc list-inside mt-1 space-y-1">
                <li>YouTube: youtube.com/watch?v=ID</li>
                <li>YouTube: youtu.be/ID</li>
                <li>Vimeo: vimeo.com/ID</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    `

    this.errorMessageTarget.classList.remove("hidden")

    // Announce error to screen readers
    this.errorMessageTarget.setAttribute("role", "alert")
    this.errorMessageTarget.setAttribute("aria-live", "assertive")
  }

  isValidUrl(url) {
    return this.extractVideoInfo(url) !== null
  }

  getEmbedUrl() {
    if (!this.currentPlatformValue || !this.currentVideoIdValue) {
      return null
    }

    if (this.currentPlatformValue === "youtube") {
      return `https://www.youtube.com/embed/${this.currentVideoIdValue}`
    } else if (this.currentPlatformValue === "vimeo") {
      return `https://player.vimeo.com/video/${this.currentVideoIdValue}`
    }

    return null
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
