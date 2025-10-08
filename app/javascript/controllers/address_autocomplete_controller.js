import { Controller } from "@hotwired/stimulus"

// Enhanced Address Autocomplete Controller with EU Focus & Detailed Fields
// Connects to data-controller="address-autocomplete"
export default class extends Controller {
  static targets = [
    "input",
    "latitude",
    "longitude",
    "country",
    "companyName",
    "street",
    "streetNumber",
    "city",
    "state",
    "postalCode",
    "detailsSection",
    "mapContainer",
    "toggleButton"
  ]

  connect() {
    this.detailsVisible = false
    if (typeof google !== "undefined" && google.maps && google.maps.places) {
      this.initAutocomplete()
    } else {
      // Wait for Google Maps to load (it's loaded via script tag in layout)
      this.waitForGoogleMaps()
    }
  }

  waitForGoogleMaps() {
    if (typeof google !== "undefined" && google.maps && google.maps.places) {
      this.initAutocomplete()
    } else {
      setTimeout(() => this.waitForGoogleMaps(), 100)
    }
  }

  initAutocomplete() {
    const autocomplete = new google.maps.places.Autocomplete(this.inputTarget, {
      fields: ["address_components", "geometry", "formatted_address", "name", "types"],
      componentRestrictions: {
        country: [
          "DE", "PL", "AT", "CH", "FR", "IT", "NL", "BE",
          "ES", "CZ", "SK", "HU", "RO", "BG", "HR", "SI"
        ]
      }
    })

    autocomplete.addListener("place_changed", () => {
      const place = autocomplete.getPlace()

      if (place.geometry) {
        this.populateFields(place)
        this.updateMap(place.geometry.location)

        // Auto-show details section when address is selected
        if (!this.detailsVisible) {
          this.toggleDetails()
        }
      }
    })
  }

  populateFields(place) {
    // Update main address field with formatted address
    this.inputTarget.value = place.formatted_address

    // Update coordinates
    if (this.hasLatitudeTarget) {
      this.latitudeTarget.value = place.geometry.location.lat()
    }
    if (this.hasLongitudeTarget) {
      this.longitudeTarget.value = place.geometry.location.lng()
    }

    // Parse address components
    const components = {}
    place.address_components?.forEach(component => {
      const types = component.types
      if (types.includes("street_number")) {
        components.streetNumber = component.long_name
      }
      if (types.includes("route")) {
        components.street = component.long_name
      }
      if (types.includes("locality")) {
        components.city = component.long_name
      }
      if (types.includes("administrative_area_level_1")) {
        components.state = component.long_name
      }
      if (types.includes("postal_code")) {
        components.postalCode = component.long_name
      }
      if (types.includes("country")) {
        components.country = component.short_name
      }
    })

    // Extract company name (if place is an establishment)
    const companyName = (place.types?.includes("establishment") || place.types?.includes("point_of_interest"))
      ? place.name
      : ""

    // Update all detail fields
    if (this.hasCompanyNameTarget) {
      this.companyNameTarget.value = companyName || ""
    }
    if (this.hasStreetTarget) {
      this.streetTarget.value = components.street || ""
    }
    if (this.hasStreetNumberTarget) {
      this.streetNumberTarget.value = components.streetNumber || ""
    }
    if (this.hasCityTarget) {
      this.cityTarget.value = components.city || ""
    }
    if (this.hasStateTarget) {
      this.stateTarget.value = components.state || ""
    }
    if (this.hasPostalCodeTarget) {
      this.postalCodeTarget.value = components.postalCode || ""
    }
    if (this.hasCountryTarget) {
      this.countryTarget.value = components.country || ""
    }

    // Update collapsed header display
    this.updateCollapsedDisplay(place.formatted_address)
  }

  updateCollapsedDisplay(address) {
    // Find the display text element in the collapsed header
    const displayText = this.toggleButtonTarget?.querySelector('.display-text')
    if (displayText && address) {
      displayText.textContent = address
    }
  }

  updateMap(location) {
    if (!this.hasMapContainerTarget) return

    // Clear existing map
    this.mapContainerTarget.innerHTML = ""

    // Create new map
    const map = new google.maps.Map(this.mapContainerTarget, {
      center: location,
      zoom: 15,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: true,
      zoomControl: true
    })

    // Add marker
    new google.maps.Marker({
      position: location,
      map: map,
      title: "Selected Location"
    })
  }

  toggleDetails() {
    if (!this.hasDetailsSectionTarget || !this.hasToggleButtonTarget) return

    this.detailsVisible = !this.detailsVisible

    // Find chevron icon inside toggle button
    const chevron = this.toggleButtonTarget.querySelector('.chevron-icon')

    if (this.detailsVisible) {
      this.detailsSectionTarget.classList.remove("hidden")
      if (chevron) {
        chevron.style.transform = 'rotate(180deg)'
      }
    } else {
      this.detailsSectionTarget.classList.add("hidden")
      if (chevron) {
        chevron.style.transform = 'rotate(0deg)'
      }
    }
  }

  clearFields() {
    this.inputTarget.value = ""

    const targets = [
      "latitude", "longitude", "country", "companyName",
      "street", "streetNumber", "city", "state", "postalCode"
    ]

    targets.forEach(targetName => {
      const targetKey = `${targetName}Target`
      if (this[targetKey]) {
        this[targetKey].value = ""
      }
    })

    if (this.hasMapContainerTarget) {
      this.mapContainerTarget.innerHTML = ""
    }

    if (this.detailsVisible) {
      this.toggleDetails()
    }
  }

  get apiKey() {
    return document.querySelector('meta[name="google-maps-api-key"]')?.content
  }
}
