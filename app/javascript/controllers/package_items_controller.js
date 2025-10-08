import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="package-items"
export default class extends Controller {
  static targets = ["template", "container", "summary"]
  static values = { presets: Object }

  connect() {
    this.updateSummary()
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML('beforeend', content)
    this.updateSummary()
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest('.package-item')

    // Mark for deletion if persisted
    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = '1'
      item.style.display = 'none'
    } else {
      item.remove()
    }

    this.updateSummary()
  }

  typeChanged(event) {
    const select = event.target
    const packageType = select.value
    const preset = this.presetsValue[packageType]

    if (preset) {
      const item = select.closest('.package-item')
      const lengthInput = item.querySelector('[name*="[length_cm]"]')
      const widthInput = item.querySelector('[name*="[width_cm]"]')
      const heightInput = item.querySelector('[name*="[height_cm]"]')
      const weightInput = item.querySelector('[name*="[weight_kg]"]')

      if (lengthInput && preset.length) lengthInput.value = preset.length
      if (widthInput && preset.width) widthInput.value = preset.width
      if (heightInput && preset.height) heightInput.value = preset.height
      if (weightInput && preset.weight) weightInput.value = preset.weight
    }

    this.updateSummary()
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return

    let totalPackages = 0
    let totalWeight = 0

    this.containerTarget.querySelectorAll('.package-item:not([style*="display: none"])').forEach(item => {
      const quantity = parseInt(item.querySelector('[name*="[quantity]"]')?.value) || 0
      const weight = parseFloat(item.querySelector('[name*="[weight_kg]"]')?.value) || 0
      totalPackages += quantity
      totalWeight += quantity * weight
    })

    this.summaryTarget.innerHTML = `
      Packstück(e): <strong>${totalPackages}</strong>
      Gesamtgewicht: <strong>${totalWeight.toFixed(2)}kg</strong>
    `
  }
}
