# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_05_184929) do
  create_table "carrier_requests", force: :cascade do |t|
    t.integer "transport_request_id", null: false
    t.integer "carrier_id", null: false
    t.string "status"
    t.decimal "distance_to_pickup_km"
    t.decimal "distance_to_delivery_km"
    t.boolean "in_radius"
    t.datetime "email_sent_at"
    t.datetime "response_date"
    t.decimal "offered_price"
    t.datetime "offered_delivery_date"
    t.string "transport_type"
    t.string "vehicle_type"
    t.string "driver_language"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_carrier_requests_on_carrier_id"
    t.index ["transport_request_id"], name: "index_carrier_requests_on_transport_request_id"
  end

  create_table "carriers", force: :cascade do |t|
    t.string "company_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.string "preferred_contact_method"
    t.string "language"
    t.string "country"
    t.text "address"
    t.decimal "latitude"
    t.decimal "longitude"
    t.integer "pickup_radius_km"
    t.boolean "ignore_radius"
    t.boolean "has_transporter"
    t.boolean "has_lkw"
    t.integer "lkw_length_cm"
    t.integer "lkw_width_cm"
    t.integer "lkw_height_cm"
    t.boolean "has_liftgate"
    t.boolean "has_pallet_jack"
    t.boolean "has_gps_tracking"
    t.boolean "blacklisted"
    t.decimal "rating_communication"
    t.decimal "rating_punctuality"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "pickup_countries"
    t.text "delivery_countries"
  end

  create_table "transport_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "status"
    t.string "start_country"
    t.text "start_address"
    t.decimal "start_latitude"
    t.decimal "start_longitude"
    t.string "destination_country"
    t.text "destination_address"
    t.decimal "destination_latitude"
    t.decimal "destination_longitude"
    t.integer "distance_km"
    t.datetime "pickup_date_from"
    t.datetime "pickup_date_to"
    t.datetime "delivery_date_from"
    t.datetime "delivery_date_to"
    t.string "vehicle_type"
    t.integer "cargo_length_cm"
    t.integer "cargo_width_cm"
    t.integer "cargo_height_cm"
    t.integer "cargo_weight_kg"
    t.decimal "loading_meters"
    t.boolean "requires_liftgate"
    t.boolean "requires_pallet_jack"
    t.boolean "requires_side_loading"
    t.boolean "requires_tarp"
    t.boolean "requires_gps_tracking"
    t.string "driver_language"
    t.string "matchmaking_status"
    t.integer "matched_carrier_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["matched_carrier_id"], name: "index_transport_requests_on_matched_carrier_id"
    t.index ["user_id"], name: "index_transport_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "dispatcher", null: false
    t.string "company_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "carrier_requests", "carriers"
  add_foreign_key "carrier_requests", "transport_requests"
  add_foreign_key "transport_requests", "carriers", column: "matched_carrier_id"
  add_foreign_key "transport_requests", "users"
end
