class MakeMatchedCarrierIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :transport_requests, :matched_carrier_id, true
  end
end
