class AddCountryArraysToCarriers < ActiveRecord::Migration[8.0]
  def change
    add_column :carriers, :pickup_countries, :text
    add_column :carriers, :delivery_countries, :text
  end
end
