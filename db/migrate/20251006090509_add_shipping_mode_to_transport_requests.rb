class AddShippingModeToTransportRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :transport_requests, :shipping_mode, :string, default: 'packages' unless column_exists?(:transport_requests, :shipping_mode)
    add_column :transport_requests, :total_height_cm, :integer unless column_exists?(:transport_requests, :total_height_cm)
    add_column :transport_requests, :total_weight_kg, :decimal, precision: 10, scale: 2 unless column_exists?(:transport_requests, :total_weight_kg)
    add_column :transport_requests, :pickup_time_from, :string unless column_exists?(:transport_requests, :pickup_time_from)
    add_column :transport_requests, :pickup_time_to, :string unless column_exists?(:transport_requests, :pickup_time_to)
    add_column :transport_requests, :delivery_time_from, :string unless column_exists?(:transport_requests, :delivery_time_from)
    add_column :transport_requests, :delivery_time_to, :string unless column_exists?(:transport_requests, :delivery_time_to)
  end
end
