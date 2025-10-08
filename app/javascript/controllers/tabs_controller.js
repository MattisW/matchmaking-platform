import { Controller } from "@hotwired/stimulus"

// Tabs Controller
// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.showTab(0)
  }

  show(event) {
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.showTab(index)
  }

  showTab(index) {
    // Hide all panels and deactivate all tabs
    this.panelTargets.forEach(panel => {
      panel.classList.add('hidden')
    })

    this.tabTargets.forEach(tab => {
      tab.classList.remove('border-blue-600', 'text-blue-600')
      tab.classList.add('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
    })

    // Show selected panel and activate selected tab
    this.panelTargets[index].classList.remove('hidden')
    this.tabTargets[index].classList.add('border-blue-600', 'text-blue-600')
    this.tabTargets[index].classList.remove('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
  }
}
