import { Controller } from "@hotwired/stimulus"

// Google Places Autocomplete Controller
// Connects to data-controller="autocomplete"
export default class extends Controller {
  static targets = ["input", "latitude", "longitude", "country"]

  connect() {
    if (typeof google !== 'undefined' && google.maps) {
      this.initAutocomplete()
    } else {
      this.loadGoogleMaps()
    }
  }

  loadGoogleMaps() {
    const script = document.createElement('script')
    script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKey}&libraries=places`
    script.addEventListener('load', () => this.initAutocomplete())
    document.head.appendChild(script)
  }

  initAutocomplete() {
    const autocomplete = new google.maps.places.Autocomplete(this.inputTarget, {
      types: ['address']
    })

    autocomplete.addListener('place_changed', () => {
      const place = autocomplete.getPlace()

      if (place.geometry) {
        // Update hidden fields with coordinates
        if (this.hasLatitudeTarget) {
          this.latitudeTarget.value = place.geometry.location.lat()
        }
        if (this.hasLongitudeTarget) {
          this.longitudeTarget.value = place.geometry.location.lng()
        }

        // Extract country code
        const countryComponent = place.address_components?.find(
          component => component.types.includes('country')
        )
        if (countryComponent && this.hasCountryTarget) {
          this.countryTarget.value = countryComponent.short_name
        }

        // Update the input field with formatted address
        this.inputTarget.value = place.formatted_address
      }
    })
  }

  get apiKey() {
    return document.querySelector('meta[name="google-maps-api-key"]')?.content
  }
}
