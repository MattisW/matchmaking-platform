class CreatePackageItems < ActiveRecord::Migration[8.0]
  def change
    create_table :package_items do |t|
      t.references :transport_request, null: false, foreign_key: true
      t.string :package_type, null: false
      t.integer :quantity, default: 1
      t.integer :length_cm
      t.integer :width_cm
      t.integer :height_cm
      t.decimal :weight_kg, precision: 10, scale: 2

      t.timestamps
    end

    add_index :package_items, [:transport_request_id, :package_type]
  end
end
