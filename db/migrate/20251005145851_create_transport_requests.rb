class CreateTransportRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :transport_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.string :start_country
      t.text :start_address
      t.decimal :start_latitude
      t.decimal :start_longitude
      t.string :destination_country
      t.text :destination_address
      t.decimal :destination_latitude
      t.decimal :destination_longitude
      t.integer :distance_km
      t.datetime :pickup_date_from
      t.datetime :pickup_date_to
      t.datetime :delivery_date_from
      t.datetime :delivery_date_to
      t.string :vehicle_type
      t.integer :cargo_length_cm
      t.integer :cargo_width_cm
      t.integer :cargo_height_cm
      t.integer :cargo_weight_kg
      t.decimal :loading_meters
      t.boolean :requires_liftgate
      t.boolean :requires_pallet_jack
      t.boolean :requires_side_loading
      t.boolean :requires_tarp
      t.boolean :requires_gps_tracking
      t.string :driver_language
      t.string :matchmaking_status
      t.references :matched_carrier, null: false, foreign_key: true

      t.timestamps
    end
  end
end
