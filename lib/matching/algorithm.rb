module Matching
  class Algorithm
    attr_reader :transport_request

    def initialize(transport_request)
      @transport_request = transport_request
      @matched_carriers = []
    end

    def run
      # Start with all active carriers
      carriers = Carrier.active

      # Apply filters sequentially
      carriers = filter_by_vehicle_type(carriers)
      carriers = filter_by_coverage(carriers)
      carriers = filter_by_radius(carriers)
      carriers = filter_by_capacity(carriers)
      carriers = filter_by_equipment(carriers)

      # Create CarrierRequest records for matches
      create_matches(carriers)

      @matched_carriers.count
    end

    private

    def filter_by_vehicle_type(carriers)
      case transport_request.vehicle_type
      when "transporter"
        carriers.where(has_transporter: true)
      when "lkw"
        carriers.where(has_lkw: true)
      when "either", nil
        carriers
      else
        carriers
      end
    end

    def filter_by_coverage(carriers)
      # Filter carriers that cover both pickup and delivery countries
      return carriers unless transport_request.start_country.present? && transport_request.destination_country.present?

      carriers.select do |carrier|
        pickup_countries = carrier.pickup_countries || []
        delivery_countries = carrier.delivery_countries || []

        pickup_countries.include?(transport_request.start_country) &&
        delivery_countries.include?(transport_request.destination_country)
      end
    end

    def filter_by_radius(carriers)
      return carriers unless transport_request.start_latitude && transport_request.start_longitude

      carriers.select do |carrier|
        # Skip radius check if carrier ignores radius
        next true if carrier.ignore_radius

        # Skip if carrier has no location or radius set
        next false unless carrier.latitude && carrier.longitude && carrier.pickup_radius_km

        # Calculate distance from carrier to pickup point
        distance = DistanceCalculator.haversine(
          carrier.latitude,
          carrier.longitude,
          transport_request.start_latitude,
          transport_request.start_longitude
        )

        distance && distance <= carrier.pickup_radius_km
      end
    end

    def filter_by_capacity(carriers)
      # Only filter if LKW is required and dimensions are specified
      return carriers unless transport_request.vehicle_type == "lkw"
      return carriers unless transport_request.cargo_length_cm || transport_request.cargo_width_cm || transport_request.cargo_height_cm

      carriers.select do |carrier|
        next false unless carrier.has_lkw

        # Check if carrier's LKW can accommodate cargo
        length_ok = !transport_request.cargo_length_cm || !carrier.lkw_length_cm || carrier.lkw_length_cm >= transport_request.cargo_length_cm
        width_ok = !transport_request.cargo_width_cm || !carrier.lkw_width_cm || carrier.lkw_width_cm >= transport_request.cargo_width_cm
        height_ok = !transport_request.cargo_height_cm || !carrier.lkw_height_cm || carrier.lkw_height_cm >= transport_request.cargo_height_cm

        length_ok && width_ok && height_ok
      end
    end

    def filter_by_equipment(carriers)
      carriers.select do |carrier|
        # Check liftgate requirement
        liftgate_ok = !transport_request.requires_liftgate || carrier.has_liftgate

        # Check pallet jack requirement
        pallet_jack_ok = !transport_request.requires_pallet_jack || carrier.has_pallet_jack

        # Check GPS tracking requirement
        gps_ok = !transport_request.requires_gps_tracking || carrier.has_gps_tracking

        liftgate_ok && pallet_jack_ok && gps_ok
      end
    end

    def create_matches(carriers)
      carriers.each do |carrier|
        # Calculate distances
        distance_to_pickup = if carrier.latitude && transport_request.start_latitude
          DistanceCalculator.haversine(
            carrier.latitude,
            carrier.longitude,
            transport_request.start_latitude,
            transport_request.start_longitude
          )
        end

        distance_to_delivery = if carrier.latitude && transport_request.destination_latitude
          DistanceCalculator.haversine(
            carrier.latitude,
            carrier.longitude,
            transport_request.destination_latitude,
            transport_request.destination_longitude
          )
        end

        in_radius = if carrier.pickup_radius_km && distance_to_pickup
          distance_to_pickup <= carrier.pickup_radius_km
        else
          carrier.ignore_radius
        end

        # Create CarrierRequest record
        carrier_request = CarrierRequest.create!(
          transport_request: transport_request,
          carrier: carrier,
          status: "new",
          distance_to_pickup_km: distance_to_pickup&.round(2),
          distance_to_delivery_km: distance_to_delivery&.round(2),
          in_radius: in_radius
        )

        @matched_carriers << carrier if carrier_request.persisted?
      end
    end
  end
end
