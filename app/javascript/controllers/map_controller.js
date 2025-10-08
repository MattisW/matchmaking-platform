import { Controller } from "@hotwired/stimulus"

// Google Maps Display Controller
// Connects to data-controller="map"
export default class extends Controller {
  static targets = ["container"]
  static values = {
    startLat: Number,
    startLng: Number,
    destLat: Number,
    destLng: Number,
    singleLat: Number,
    singleLng: Number,
    radius: Number,        // Service radius in km
    showRadius: Boolean    // Whether to show radius circle
  }

  connect() {
    if (typeof google !== 'undefined' && google.maps) {
      this.initMap()
    } else {
      this.loadGoogleMaps()
    }
  }

  loadGoogleMaps() {
    const script = document.createElement('script')
    script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKey}`
    script.addEventListener('load', () => this.initMap())
    document.head.appendChild(script)
  }

  initMap() {
    const bounds = new google.maps.LatLngBounds()

    const map = new google.maps.Map(this.containerTarget, {
      zoom: 6,
      mapTypeControl: true,
      streetViewControl: false,
      fullscreenControl: true
    })

    // Check if this is a route map (start + destination) or single location map
    if (this.hasStartLatValue && this.hasStartLngValue && this.hasDestLatValue && this.hasDestLngValue) {
      // Route map - show start and destination with markers
      const startMarker = new google.maps.Marker({
        position: { lat: this.startLatValue, lng: this.startLngValue },
        map: map,
        title: 'Pickup',
        label: 'A',
        icon: {
          url: 'http://maps.google.com/mapfiles/ms/icons/green-dot.png'
        }
      })
      bounds.extend(startMarker.getPosition())

      const destMarker = new google.maps.Marker({
        position: { lat: this.destLatValue, lng: this.destLngValue },
        map: map,
        title: 'Delivery',
        label: 'B',
        icon: {
          url: 'http://maps.google.com/mapfiles/ms/icons/red-dot.png'
        }
      })
      bounds.extend(destMarker.getPosition())

      // Draw a line between start and destination
      const routeLine = new google.maps.Polyline({
        path: [
          { lat: this.startLatValue, lng: this.startLngValue },
          { lat: this.destLatValue, lng: this.destLngValue }
        ],
        geodesic: true,
        strokeColor: '#2563EB',
        strokeOpacity: 0.7,
        strokeWeight: 3,
        map: map
      })

      map.fitBounds(bounds)
    } else if (this.hasSingleLatValue && this.hasSingleLngValue) {
      // Single location map - show one marker
      const marker = new google.maps.Marker({
        position: { lat: this.singleLatValue, lng: this.singleLngValue },
        map: map,
        title: 'Location'
      })

      map.setCenter(marker.getPosition())

      // Add radius circle if enabled
      if (this.hasShowRadiusValue && this.showRadiusValue && this.hasRadiusValue && this.radiusValue > 0) {
        const radiusCircle = new google.maps.Circle({
          map: map,
          center: { lat: this.singleLatValue, lng: this.singleLngValue },
          radius: this.radiusValue * 1000, // Convert km to meters
          strokeColor: '#3B82F6',
          strokeOpacity: 0.8,
          strokeWeight: 2,
          fillColor: '#3B82F6',
          fillOpacity: 0.15
        })

        // Fit map bounds to include the entire circle
        map.fitBounds(radiusCircle.getBounds())
      } else {
        map.setZoom(12)
      }
    }
  }

  get apiKey() {
    return document.querySelector('meta[name="google-maps-api-key"]')?.content
  }
}
