class FixMatchedCarrierForeignKey < ActiveRecord::Migration[8.0]
  def change
    # Remove incorrect foreign key constraint
    remove_foreign_key :transport_requests, column: :matched_carrier_id if foreign_key_exists?(:transport_requests, column: :matched_carrier_id)

    # Add correct foreign key to carriers table
    add_foreign_key :transport_requests, :carriers, column: :matched_carrier_id
  end
end
