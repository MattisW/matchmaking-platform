class Admin::TransportRequestsController < ApplicationController
  layout 'admin'
  before_action :authenticate_user!
  before_action :set_transport_request, only: [:show, :edit, :update, :destroy, :run_matching, :cancel]

  def index
    @transport_requests = TransportRequest.includes(:user, :matched_carrier)
                                          .order(created_at: :desc)
                                          .page(params[:page])
  end

  def show
    @carrier_requests = @transport_request.carrier_requests
                                          .includes(:carrier)
                                          .order(created_at: :desc)
  end

  def new
    @transport_request = current_user.transport_requests.build
  end

  def create
    @transport_request = current_user.transport_requests.build(transport_request_params)
    @transport_request.status = 'new'

    # Geocode addresses before saving
    geocode_addresses(@transport_request)

    if @transport_request.save
      redirect_to admin_transport_request_path(@transport_request), notice: 'Transport request was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Re-geocode if addresses changed
    if transport_request_params[:start_address] != @transport_request.start_address ||
       transport_request_params[:destination_address] != @transport_request.destination_address
      @transport_request.assign_attributes(transport_request_params)
      geocode_addresses(@transport_request)
    end

    if @transport_request.update(transport_request_params)
      redirect_to admin_transport_request_path(@transport_request), notice: 'Transport request was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transport_request.destroy
    redirect_to admin_transport_requests_path, notice: 'Transport request was successfully deleted.'
  end

  def run_matching
    if @transport_request.status == 'new'
      MatchCarriersJob.perform_later(@transport_request.id)
      @transport_request.update(status: 'matching')
      redirect_to admin_transport_request_path(@transport_request), notice: 'Matching process started. Invitations will be sent shortly.'
    else
      redirect_to admin_transport_request_path(@transport_request), alert: 'Cannot run matching for this request.'
    end
  end

  def cancel
    @transport_request.update(status: 'cancelled')
    redirect_to admin_transport_request_path(@transport_request), notice: 'Transport request was cancelled.'
  end

  private

  def set_transport_request
    @transport_request = TransportRequest.find(params[:id])
  end

  def transport_request_params
    params.require(:transport_request).permit(
      :start_address, :destination_address,
      :pickup_date_from, :pickup_date_to,
      :delivery_date_from, :delivery_date_to,
      :vehicle_type, :cargo_length_cm, :cargo_width_cm, :cargo_height_cm,
      :cargo_weight_kg, :loading_meters,
      :requires_liftgate, :requires_pallet_jack, :requires_side_loading,
      :requires_tarp, :requires_gps_tracking, :driver_language
    )
  end

  def geocode_addresses(request)
    # Geocode start address
    if request.start_address.present?
      start_result = Geocoder.search(request.start_address).first
      if start_result
        request.start_latitude = start_result.latitude
        request.start_longitude = start_result.longitude
        request.start_country = start_result.country_code&.upcase
      end
    end

    # Geocode destination address
    if request.destination_address.present?
      dest_result = Geocoder.search(request.destination_address).first
      if dest_result
        request.destination_latitude = dest_result.latitude
        request.destination_longitude = dest_result.longitude
        request.destination_country = dest_result.country_code&.upcase
      end
    end

    # Calculate distance
    if request.start_latitude && request.destination_latitude
      request.distance_km = Geocoder::Calculations.distance_between(
        [request.start_latitude, request.start_longitude],
        [request.destination_latitude, request.destination_longitude]
      ).round
    end
  end
end
