Geocoder.configure(
  lookup: :google,
  api_key: Rails.application.credentials.dig(:google_maps, :api_key),
  use_https: true,
  units: :km,
  timeout: 5
)
