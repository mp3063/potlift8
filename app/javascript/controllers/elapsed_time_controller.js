import { Controller } from "@hotwired/stimulus"

// Ticks an m:ss counter up from the server's elapsed seconds.
// Counting from the server's figure (not a start timestamp) keeps it right
// when the browser clock is off.
export default class extends Controller {
  static values = { seconds: Number }

  // Fires before connect() and again when a morph updates the value;
  // it only resets the origin, so it needs no connect guard.
  secondsValueChanged() {
    this.origin = Date.now() - this.secondsValue * 1000
  }

  connect() {
    this.render()
    this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const seconds = Math.max(0, Math.floor((Date.now() - this.origin) / 1000))
    this.element.textContent = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`
  }
}
