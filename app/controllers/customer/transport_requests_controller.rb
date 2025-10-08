module Customer
  class TransportRequestsController < BaseController
    before_action :set_transport_request, only: [ :show, :edit, :update, :cancel ]

    def index
      @transport_requests = current_user.transport_requests
                                         .order(created_at: :desc)
    end

    def show
      @carrier_requests = @transport_request.carrier_requests
                                             .includes(:carrier)
                                             .where(status: [ "offered", "won", "rejected" ])
                                             .order(offered_price: :asc)
    end

    def new
      @transport_request = current_user.transport_requests.build
    end

    def create
      @transport_request = current_user.transport_requests.build(transport_request_params)
      @transport_request.status = "new"

      # Calculate distance if coordinates are present
      if @transport_request.start_latitude && @transport_request.destination_latitude
        @transport_request.distance_km = Geocoder::Calculations.distance_between(
          [ @transport_request.start_latitude, @transport_request.start_longitude ],
          [ @transport_request.destination_latitude, @transport_request.destination_longitude ]
        ).round
      end

      # Geocode addresses before saving (using params from autocomplete)
      if @transport_request.save
        # Generate quote automatically
        quote = Pricing::Calculator.new(@transport_request).calculate

        if quote
          redirect_to customer_transport_request_path(@transport_request),
                      notice: t('transport_requests.created_with_quote')
        else
          redirect_to customer_transport_request_path(@transport_request),
                      alert: t('transport_requests.created_no_quote')
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @transport_request.update(transport_request_params)
        redirect_to customer_transport_request_path(@transport_request),
                    notice: "Request updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def cancel
      @transport_request.update(status: "cancelled")
      redirect_to customer_transport_request_path(@transport_request),
                  notice: "Request cancelled successfully."
    end

    private

    def set_transport_request
      @transport_request = current_user.transport_requests.find(params[:id])
    end

    def transport_request_params
      params.require(:transport_request).permit(
        :start_address, :destination_address,
        :start_latitude, :start_longitude, :start_country,
        :destination_latitude, :destination_longitude, :destination_country,
        :distance_km,
        :start_company_name, :start_street, :start_street_number,
        :start_city, :start_state, :start_postal_code, :start_notes,
        :destination_company_name, :destination_street, :destination_street_number,
        :destination_city, :destination_state, :destination_postal_code, :destination_notes,
        :pickup_date_from, :pickup_date_to, :pickup_notes,
        :delivery_date_from, :delivery_date_to, :delivery_notes,
        :vehicle_type, :cargo_length_cm, :cargo_width_cm, :cargo_height_cm,
        :cargo_weight_kg, :loading_meters,
        :requires_liftgate, :requires_pallet_jack, :requires_side_loading,
        :requires_tarp, :requires_gps_tracking, :driver_language,
        # Cargo management params
        :shipping_mode, :total_height_cm, :total_weight_kg,
        package_items_attributes: [
          :id, :package_type, :quantity,
          :length_cm, :width_cm, :height_cm, :weight_kg,
          :_destroy
        ]
      )
    end
  end
end
