class CreateCarrierRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :carrier_requests do |t|
      t.references :transport_request, null: false, foreign_key: true
      t.references :carrier, null: false, foreign_key: true
      t.string :status
      t.decimal :distance_to_pickup_km
      t.decimal :distance_to_delivery_km
      t.boolean :in_radius
      t.datetime :email_sent_at
      t.datetime :response_date
      t.decimal :offered_price
      t.datetime :offered_delivery_date
      t.string :transport_type
      t.string :vehicle_type
      t.string :driver_language
      t.text :notes

      t.timestamps
    end
  end
end
