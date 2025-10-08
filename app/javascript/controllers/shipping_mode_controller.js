import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="shipping-mode"
export default class extends Controller {
  static targets = ["panel", "modeInput", "tab"]
  static values = { defaultMode: String }

  connect() {
    const mode = this.defaultModeValue || 'packages'
    this.showMode(mode)
  }

  switch(event) {
    event.preventDefault()
    const mode = event.currentTarget.dataset.mode
    this.showMode(mode)
  }

  showMode(mode) {
    // Update hidden field
    if (this.hasModeInputTarget) {
      this.modeInputTarget.value = mode
    }

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.mode === mode) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })

    // Update tab styling
    this.tabTargets.forEach(tab => {
      if (tab.dataset.mode === mode) {
        tab.classList.add('border-blue-600', 'text-blue-600')
        tab.classList.remove('border-transparent', 'text-gray-500')
      } else {
        tab.classList.remove('border-blue-600', 'text-blue-600')
        tab.classList.add('border-transparent', 'text-gray-500')
      }
    })
  }
}
