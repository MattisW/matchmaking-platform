class CreatePackageTypePresets < ActiveRecord::Migration[8.0]
  def change
    create_table :package_type_presets do |t|
      t.string :name, null: false
      t.string :category
      t.integer :default_length_cm
      t.integer :default_width_cm
      t.integer :default_height_cm
      t.decimal :default_weight_kg, precision: 10, scale: 2

      t.timestamps
    end

    add_index :package_type_presets, :name, unique: true
  end
end
