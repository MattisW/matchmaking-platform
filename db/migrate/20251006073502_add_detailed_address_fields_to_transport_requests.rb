class AddDetailedAddressFieldsToTransportRequests < ActiveRecord::Migration[8.0]
  def change
    # Pickup/Start Address Detailed Fields
    add_column :transport_requests, :start_company_name, :string
    add_column :transport_requests, :start_street, :string
    add_column :transport_requests, :start_street_number, :string
    add_column :transport_requests, :start_city, :string
    add_column :transport_requests, :start_state, :string
    add_column :transport_requests, :start_postal_code, :string
    add_column :transport_requests, :start_notes, :text
    add_column :transport_requests, :pickup_notes, :text

    # Delivery/Destination Address Detailed Fields
    add_column :transport_requests, :destination_company_name, :string
    add_column :transport_requests, :destination_street, :string
    add_column :transport_requests, :destination_street_number, :string
    add_column :transport_requests, :destination_city, :string
    add_column :transport_requests, :destination_state, :string
    add_column :transport_requests, :destination_postal_code, :string
    add_column :transport_requests, :destination_notes, :text
    add_column :transport_requests, :delivery_notes, :text
  end
end
