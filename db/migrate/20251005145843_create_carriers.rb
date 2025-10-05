class CreateCarriers < ActiveRecord::Migration[8.0]
  def change
    create_table :carriers do |t|
      t.string :company_name
      t.string :contact_email
      t.string :contact_phone
      t.string :preferred_contact_method
      t.string :language
      t.string :country
      t.text :address
      t.decimal :latitude
      t.decimal :longitude
      t.integer :pickup_radius_km
      t.boolean :ignore_radius
      t.boolean :has_transporter
      t.boolean :has_lkw
      t.integer :lkw_length_cm
      t.integer :lkw_width_cm
      t.integer :lkw_height_cm
      t.boolean :has_liftgate
      t.boolean :has_pallet_jack
      t.boolean :has_gps_tracking
      t.boolean :blacklisted
      t.decimal :rating_communication
      t.decimal :rating_punctuality
      t.text :notes

      t.timestamps
    end
  end
end
