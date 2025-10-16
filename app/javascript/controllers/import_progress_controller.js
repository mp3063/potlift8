import { Controller } from "@hotwired/stimulus"

/**
 * Import Progress Controller
 *
 * Polls the server for import job progress and updates the UI dynamically.
 * Displays processing, completed, or failed states with real-time updates.
 *
 * Features:
 * - Polls progress endpoint every 2 seconds
 * - Updates progress bar and percentage
 * - Shows stats when completed
 * - Auto-reloads page when job finishes
 * - Cleans up polling on disconnect
 *
 * @example
 *   <div data-controller="import-progress"
 *        data-import-progress-job-id-value="job123"
 *        data-import-progress-status-value="processing">
 *     <!-- Progress UI -->
 *   </div>
 */
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

    // Start polling if job is still processing
    if (this.statusValue === "processing") {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  /**
   * Start polling the progress endpoint
   */
  startPolling() {
    // Poll every 2 seconds
    this.pollInterval = setInterval(() => {
      this.fetchProgress()
    }, 2000)
  }

  /**
   * Stop polling
   */
  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  /**
   * Fetch current progress from server
   */
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

  /**
   * Update UI based on progress data
   */
  updateUI(data) {
    const { status, progress, imported, updated, errors } = data

    // Update progress bar and percentage if still processing
    if (status === "processing" && progress !== undefined) {
      this.updateProgress(progress)
    }

    // Handle state transitions
    if (status !== this.statusValue) {
      this.statusValue = status
      this.transitionState(status, data)
    }
  }

  /**
   * Update progress bar and percentage text
   */
  updateProgress(progress) {
    const percentage = Math.min(Math.max(progress, 0), 100) // Clamp 0-100

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
      this.progressBarTarget.setAttribute("aria-valuenow", percentage)
    }

    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${percentage}%`
    }
  }

  /**
   * Transition between states (processing -> completed/failed)
   */
  transitionState(newStatus, data) {
    console.log("Transitioning to state:", newStatus)

    // Hide all state containers
    if (this.hasProcessingTarget) {
      this.processingTarget.classList.add("hidden")
    }
    if (this.hasCompletedTarget) {
      this.completedTarget.classList.add("hidden")
    }
    if (this.hasFailedTarget) {
      this.failedTarget.classList.add("hidden")
    }

    // Show appropriate state container
    switch (newStatus) {
      case "completed":
        this.showCompleted(data)
        this.stopPolling()
        // Reload page after 1 second to show final state properly
        setTimeout(() => window.location.reload(), 1000)
        break

      case "failed":
        this.showFailed(data)
        this.stopPolling()
        // Reload page after 1 second to show error details
        setTimeout(() => window.location.reload(), 1000)
        break

      case "processing":
        if (this.hasProcessingTarget) {
          this.processingTarget.classList.remove("hidden")
        }
        break
    }
  }

  /**
   * Show completed state with stats
   */
  showCompleted(data) {
    if (this.hasCompletedTarget) {
      this.completedTarget.classList.remove("hidden")
    }

    // Update stats if targets exist
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

  /**
   * Show failed state
   */
  showFailed(data) {
    if (this.hasFailedTarget) {
      this.failedTarget.classList.remove("hidden")
    }
  }
}
