import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "processing",
    "completed",
    "failed",
    "progressBar",
    "percentage",
    "imported",
    "updated",
    "errors"
  ]

  static values = {
    jobId: String,
    status: String
  }

  connect() {
    console.log("Import progress controller connected", {
      jobId: this.jobIdValue,
      status: this.statusValue
    })

    if (this.statusValue === "processing" || this.statusValue === "pending") {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.fetchProgress()
    }, 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async fetchProgress() {
    try {
      const response = await fetch(`/imports/${this.jobIdValue}/progress.json`)

      if (!response.ok) {
        console.error("Failed to fetch progress:", response.statusText)
        return
      }

      const data = await response.json()
      console.log("Progress data:", data)

      this.updateUI(data)
    } catch (error) {
      console.error("Error fetching progress:", error)
    }
  }

  updateUI(data) {
    const { status, progress, imported, updated, errors } = data

    if (status === "processing" && progress !== undefined) {
      this.updateProgress(progress)
    }

    if (status !== this.statusValue) {
      this.statusValue = status
      this.transitionState(status, data)
    }
  }

  updateProgress(progress) {
    const percentage = Math.min(Math.max(progress, 0), 100)

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
      this.progressBarTarget.setAttribute("aria-valuenow", percentage)
    }

    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${percentage}%`
    }
  }

  transitionState(newStatus, data) {
    console.log("Transitioning to state:", newStatus)

    if (this.hasProcessingTarget) {
      this.processingTarget.classList.add("hidden")
    }
    if (this.hasCompletedTarget) {
      this.completedTarget.classList.add("hidden")
    }
    if (this.hasFailedTarget) {
      this.failedTarget.classList.add("hidden")
    }

    switch (newStatus) {
      case "completed":
        this.showCompleted(data)
        this.stopPolling()
        setTimeout(() => window.location.reload(), 1000)
        break

      case "failed":
        this.showFailed(data)
        this.stopPolling()
        setTimeout(() => window.location.reload(), 1000)
        break

      case "processing":
      case "pending":
        if (this.hasProcessingTarget) {
          this.processingTarget.classList.remove("hidden")
        }
        break
    }
  }

  showCompleted(data) {
    if (this.hasCompletedTarget) {
      this.completedTarget.classList.remove("hidden")
    }

    if (this.hasImportedTarget && data.imported !== undefined) {
      this.importedTarget.textContent = data.imported
    }
    if (this.hasUpdatedTarget && data.updated !== undefined) {
      this.updatedTarget.textContent = data.updated
    }
    if (this.hasErrorsTarget && data.errors !== undefined) {
      this.errorsTarget.textContent = data.errors
    }
  }

  showFailed(data) {
    if (this.hasFailedTarget) {
      this.failedTarget.classList.remove("hidden")
    }
  }
}
