class Admin::CarriersController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_carrier, only: [ :show, :edit, :update, :destroy ]

  def index
    @carriers = Carrier.includes(:carrier_requests).order(created_at: :desc).page(params[:page])
  end

  def show
    @carrier_requests = @carrier.carrier_requests.includes(:transport_request).order(created_at: :desc).page(params[:page])

    # Calculate statistics for overview tab
    @total_jobs = @carrier.carrier_requests.count
    @won_jobs = @carrier.carrier_requests.won.count
    @total_offers = @carrier.carrier_requests.offered.count
    @rejected_offers = @carrier.carrier_requests.where(status: 'rejected').count
    @success_rate = @total_offers > 0 ? (@won_jobs.to_f / @total_offers * 100).round(1) : 0

    # Calculate average rating
    ratings = [@carrier.rating_communication, @carrier.rating_punctuality].compact
    @average_rating = ratings.any? ? (ratings.sum / ratings.size.to_f).round(1) : 0
  end

  def new
    @carrier = Carrier.new
  end

  def create
    @carrier = Carrier.new(carrier_params)

    if @carrier.save
      redirect_to admin_carrier_path(@carrier), notice: "Carrier was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @carrier.update(carrier_params)
      redirect_to admin_carrier_path(@carrier), notice: "Carrier was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @carrier.destroy
    redirect_to admin_carriers_path, notice: "Carrier was successfully deleted."
  end

  private

  def set_carrier
    @carrier = Carrier.find(params[:id])
  end

  def carrier_params
    params.require(:carrier).permit(
      :company_name, :contact_email, :contact_phone, :preferred_contact_method,
      :language, :country, :address, :pickup_radius_km, :ignore_radius,
      :has_transporter, :has_lkw, :lkw_length_cm, :lkw_width_cm, :lkw_height_cm,
      :has_liftgate, :has_pallet_jack, :has_gps_tracking, :blacklisted,
      :rating_communication, :rating_punctuality, :notes,
      pickup_countries: [], delivery_countries: []
    )
  end
end
