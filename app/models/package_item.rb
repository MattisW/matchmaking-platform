class PackageItem < ApplicationRecord
  belongs_to :transport_request, inverse_of: :package_items

  # Validations
  validates :package_type, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :weight_kg, presence: true, numericality: { greater_than: 0 }
  validates :length_cm, :width_cm, :height_cm,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Calculate total weight for this package item
  def total_weight
    (weight_kg || 0) * quantity
  end

  # Get the display label for the package type
  def package_type_label
    PackageTypePreset.find_by(name: package_type.titleize)&.name || package_type.humanize
  end
end
