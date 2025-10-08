class PackageItem < ApplicationRecord
  belongs_to :transport_request

  PACKAGE_TYPES = {
    'europalette' => 'Europalette',
    'halbpalette' => 'Halbpalette',
    'viertelpalette' => 'Viertelpalette',
    'cartonage' => 'Cartonage',
    'custom' => 'Custom Package'
  }.freeze

  validates :package_type, presence: true, inclusion: { in: PACKAGE_TYPES.keys }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :length_cm, :width_cm, :height_cm, :weight_kg,
            numericality: { greater_than: 0 }, allow_nil: true

  def total_weight
    (weight_kg || 0) * quantity
  end

  def package_type_label
    PACKAGE_TYPES[package_type] || package_type
  end
end
