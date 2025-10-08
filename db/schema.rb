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

ActiveRecord::Schema[8.0].define(version: 2025_10_08_075819) do
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

  create_table "package_items", force: :cascade do |t|
    t.integer "transport_request_id", null: false
    t.string "package_type", null: false
    t.integer "quantity", default: 1
    t.integer "length_cm"
    t.integer "width_cm"
    t.integer "height_cm"
    t.decimal "weight_kg", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["transport_request_id", "package_type"], name: "index_package_items_on_transport_request_id_and_package_type"
    t.index ["transport_request_id"], name: "index_package_items_on_transport_request_id"
  end

  create_table "package_type_presets", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.integer "default_length_cm"
    t.integer "default_width_cm"
    t.integer "default_height_cm"
    t.decimal "default_weight_kg", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_package_type_presets_on_name", unique: true
  end

  create_table "pricing_rules", force: :cascade do |t|
    t.string "vehicle_type", null: false
    t.decimal "rate_per_km", precision: 10, scale: 2, null: false
    t.decimal "minimum_price", precision: 10, scale: 2, null: false
    t.decimal "weekend_surcharge_percent", precision: 5, scale: 2, default: "0.0"
    t.decimal "express_surcharge_percent", precision: 5, scale: 2, default: "0.0"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_pricing_rules_on_active"
    t.index ["vehicle_type"], name: "index_pricing_rules_on_vehicle_type"
  end

  create_table "quote_line_items", force: :cascade do |t|
    t.integer "quote_id", null: false
    t.string "description", null: false
    t.string "calculation"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "line_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id", "line_order"], name: "index_quote_line_items_on_quote_id_and_line_order"
    t.index ["quote_id"], name: "index_quote_line_items_on_quote_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.integer "transport_request_id", null: false
    t.string "status", default: "pending", null: false
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.decimal "base_price", precision: 10, scale: 2, null: false
    t.decimal "surcharge_total", precision: 10, scale: 2, default: "0.0"
    t.string "currency", default: "EUR", null: false
    t.datetime "valid_until"
    t.datetime "accepted_at"
    t.datetime "declined_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_quotes_on_status"
    t.index ["transport_request_id"], name: "index_quotes_on_transport_request_id"
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
    t.string "start_company_name"
    t.string "start_street"
    t.string "start_street_number"
    t.string "start_city"
    t.string "start_state"
    t.string "start_postal_code"
    t.text "start_notes"
    t.text "pickup_notes"
    t.string "destination_company_name"
    t.string "destination_street"
    t.string "destination_street_number"
    t.string "destination_city"
    t.string "destination_state"
    t.string "destination_postal_code"
    t.text "destination_notes"
    t.text "delivery_notes"
    t.string "shipping_mode", default: "packages"
    t.integer "total_height_cm"
    t.decimal "total_weight_kg", precision: 10, scale: 2
    t.string "pickup_time_from"
    t.string "pickup_time_to"
    t.string "delivery_time_from"
    t.string "delivery_time_to"
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
    t.string "theme_mode", default: "light", null: false
    t.string "accent_color", default: "#3B82F6", null: false
    t.string "font_size", default: "medium", null: false
    t.string "density", default: "comfortable", null: false
    t.string "avatar_url"
    t.string "locale", default: "de", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "carrier_requests", "carriers"
  add_foreign_key "carrier_requests", "transport_requests"
  add_foreign_key "package_items", "transport_requests"
  add_foreign_key "quote_line_items", "quotes"
  add_foreign_key "quotes", "transport_requests"
  add_foreign_key "transport_requests", "carriers", column: "matched_carrier_id"
  add_foreign_key "transport_requests", "users"
end
