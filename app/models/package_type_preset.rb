class PackageTypePreset < ApplicationRecord
  CATEGORIES = %w[pallet box custom].freeze

  validates :name, presence: true, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true

  def as_json_defaults
    {
      length: default_length_cm,
      width: default_width_cm,
      height: default_height_cm,
      weight: default_weight_kg
    }
  end
end
