class TransportRequest < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :matched_carrier, class_name: "Carrier", foreign_key: "matched_carrier_id", optional: true
  has_many :carrier_requests, dependent: :destroy
  has_many :carriers, through: :carrier_requests
  has_many :package_items, dependent: :destroy
  has_one :quote, dependent: :destroy
  accepts_nested_attributes_for :package_items, allow_destroy: true, reject_if: :all_blank

  # Constants
  SHIPPING_MODES = {
    'packages' => 'Paletten & mehr',
    'loading_meters' => 'Lademeter',
    'vehicle_booking' => 'Fahrzeugbuchung'
  }.freeze

  VEHICLE_TYPES_BOOKING = {
    'sprinter' => { name: 'Planen-Sprinter', max_weight: 1000, price_per_km: 0.80 },
    'sprinter_xxl' => { name: 'Planensprinter XXL', max_weight: 1100, price_per_km: 1.00 },
    'lkw_7_5' => { name: 'LKW 7,5 to.', max_weight: 2500, price_per_km: 1.15 },
    'lkw_12' => { name: 'LKW 12 to.', max_weight: 5000, price_per_km: 1.30 },
    'lkw_40' => { name: 'LKW 40 to.', max_weight: 24000, price_per_km: 1.50 }
  }.freeze

  # Validations
  validates :start_address, presence: true
  validates :destination_address, presence: true
  validates :pickup_date_from, presence: true
  validates :vehicle_type, inclusion: { in: %w[transporter lkw either], allow_nil: true }
  validates :status, inclusion: { in: %w[new quoted quote_accepted quote_declined matching matched in_transit delivered cancelled], allow_nil: true }
  validates :shipping_mode, inclusion: { in: SHIPPING_MODES.keys }, allow_nil: true
  validates :loading_meters, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 13.6 },
            if: -> { shipping_mode == 'loading_meters' }
  validate :delivery_after_pickup

  # Scopes
  scope :active, -> { where.not(status: [ "cancelled", "delivered" ]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_matching, -> { where(status: "new") }
  scope :matched, -> { where(status: "matched") }

  # Package calculations
  def total_package_weight
    package_items.sum(&:total_weight)
  end

  def total_package_count
    package_items.sum(:quantity)
  end

  private

  def delivery_after_pickup
    return unless pickup_date_from && delivery_date_from

    if delivery_date_from < pickup_date_from
      errors.add(:delivery_date_from, "must be after pickup date")
    end
  end
end
