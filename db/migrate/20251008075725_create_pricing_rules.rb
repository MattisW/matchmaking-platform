class CreatePricingRules < ActiveRecord::Migration[8.0]
  def change
    create_table :pricing_rules do |t|
      t.string :vehicle_type, null: false
      t.decimal :rate_per_km, precision: 10, scale: 2, null: false
      t.decimal :minimum_price, precision: 10, scale: 2, null: false
      t.decimal :weekend_surcharge_percent, precision: 5, scale: 2, default: 0.0
      t.decimal :express_surcharge_percent, precision: 5, scale: 2, default: 0.0
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :pricing_rules, :vehicle_type
    add_index :pricing_rules, :active
  end
end
