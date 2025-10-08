class PricingRule < ApplicationRecord
  # Vehicle types that can be priced
  VEHICLE_TYPES = %w[
    transporter
    lkw_7_5t
    lkw_12t
    lkw_18t
    lkw_24t
    sprinter
    any
  ].freeze

  # Validations
  validates :vehicle_type, presence: true, inclusion: { in: VEHICLE_TYPES }
  validates :rate_per_km, presence: true, numericality: { greater_than: 0 }
  validates :minimum_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :weekend_surcharge_percent, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :express_surcharge_percent, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_vehicle_type, ->(type) { where(vehicle_type: type) }

  # Find the pricing rule for a specific vehicle type
  # Falls back to "any" if no specific rule exists
  def self.find_for_vehicle_type(vehicle_type)
    active.for_vehicle_type(vehicle_type).first ||
      active.for_vehicle_type('any').first
  end

  # Human-readable vehicle type name
  def vehicle_type_name
    I18n.t("pricing_rules.vehicle_types.#{vehicle_type}", default: vehicle_type.humanize)
  end
end
