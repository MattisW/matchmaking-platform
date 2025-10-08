require "test_helper"

class Customer::TransportRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = users(:customer_one)
    @customer_two = users(:customer_two)
    @admin = users(:admin_user)
    @transport_request = transport_requests(:packages_mode)  # Belongs to customer_one
    @other_customer_request = transport_requests(:vehicle_booking_mode)  # Belongs to customer_two
  end

  # ========== AUTHENTICATION & AUTHORIZATION ==========

  test "should require authentication for index" do
    get customer_transport_requests_url
    assert_redirected_to new_user_session_path
  end

  test "should allow customer access" do
    sign_in @customer
    get customer_transport_requests_url
    assert_response :success
  end

  test "should deny admin access to customer area" do
    sign_in @admin
    get customer_transport_requests_url
    assert_redirected_to root_path
    assert_equal "Access denied. This area is for customers only.", flash[:alert]
  end

  test "should deny admin access to create" do
    sign_in @admin
    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }
    assert_redirected_to root_path
  end

  # ========== SCOPED TO CURRENT USER ==========

  test "index only shows current user's requests" do
    sign_in @customer

    get customer_transport_requests_url

    assert_response :success
    requests = assigns(:transport_requests)
    assert_not_nil requests
    assert requests.all? { |r| r.user_id == @customer.id }
  end

  # ========== INDEX ACTION ==========

  test "index orders by created_at desc" do
    sign_in @customer
    get customer_transport_requests_url

    requests = assigns(:transport_requests)
    assert requests.first.created_at >= requests.last.created_at if requests.count > 1
  end

  # ========== SHOW ACTION ==========

  test "show displays transport request" do
    sign_in @customer
    get customer_transport_request_url(@transport_request)

    assert_response :success
    assert_equal @transport_request, assigns(:transport_request)
  end

  test "show loads carrier requests with offers" do
    sign_in @customer
    get customer_transport_request_url(@transport_request)

    carrier_requests = assigns(:carrier_requests)
    assert_not_nil carrier_requests
    # Should only show offered/won/rejected, not 'new' or 'sent'
    assert carrier_requests.all? { |cr| %w[offered won rejected].include?(cr.status) }
  end

  test "show orders carrier requests by price asc" do
    sign_in @customer

    # Use a fresh transport request without existing carrier_requests
    fresh_request = @customer.transport_requests.create!(
      shipping_mode: 'packages',
      start_address: 'Test Start',
      destination_address: 'Test Destination',
      pickup_date_from: 2.days.from_now
    )

    # Create some carrier requests with offers
    carrier1 = carriers(:german_logistics_gmbh)
    carrier2 = carriers(:berlin_express_transport)

    fresh_request.carrier_requests.create!(
      carrier: carrier1,
      status: 'offered',
      offered_price: 500
    )
    fresh_request.carrier_requests.create!(
      carrier: carrier2,
      status: 'offered',
      offered_price: 300
    )

    get customer_transport_request_url(fresh_request)

    carrier_requests = assigns(:carrier_requests)
    prices = carrier_requests.map(&:offered_price).compact
    assert_equal prices.sort, prices, "Carrier requests should be ordered by price ascending"
  end

  # ========== NEW ACTION ==========

  test "new renders form" do
    sign_in @customer
    get new_customer_transport_request_url

    assert_response :success
    request = assigns(:transport_request)
    assert_not_nil request
    assert request.new_record?
    assert_equal @customer, request.user
  end

  # ========== CREATE ACTION ==========

  test "create with packages mode and nested package_items" do
    sign_in @customer

    assert_difference('TransportRequest.count', 1) do
      assert_difference('PackageItem.count', 2) do
        post customer_transport_requests_url, params: {
          transport_request: {
            shipping_mode: 'packages',
            start_address: 'Hamburg, Germany',
            start_latitude: 53.5511,
            start_longitude: 9.9937,
            start_country: 'DE',
            destination_address: 'Frankfurt, Germany',
            destination_latitude: 50.1109,
            destination_longitude: 8.6821,
            destination_country: 'DE',
            pickup_date_from: 2.days.from_now,
            delivery_date_from: 3.days.from_now,
            package_items_attributes: [
              {
                package_type: 'euro_pallet',
                quantity: 2,
                length_cm: 120,
                width_cm: 80,
                height_cm: 144,
                weight_kg: 300
              },
              {
                package_type: 'industrial_pallet',
                quantity: 1,
                length_cm: 120,
                width_cm: 100,
                height_cm: 144,
                weight_kg: 400
              }
            ]
          }
        }
      end
    end

    request = TransportRequest.last
    assert_equal @customer, request.user
    assert_equal 'packages', request.shipping_mode
    assert_equal 'new', request.status
    assert_equal 2, request.package_items.count
    assert_redirected_to customer_transport_request_path(request)
  end

  test "create calculates distance from coordinates" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Hamburg, Germany',
        start_latitude: 53.5511,
        start_longitude: 9.9937,
        start_country: 'DE',
        destination_address: 'Frankfurt, Germany',
        destination_latitude: 50.1109,
        destination_longitude: 8.6821,
        destination_country: 'DE',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
        ]
      }
    }

    request = TransportRequest.last
    assert_not_nil request.distance_km
    assert request.distance_km > 0
  end

  test "create generates quote automatically" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'vehicle_booking',
        vehicle_type: 'lkw',
        start_address: 'Hamburg, Germany',
        start_latitude: 53.5511,
        start_longitude: 9.9937,
        start_country: 'DE',
        destination_address: 'Frankfurt, Germany',
        destination_latitude: 50.1109,
        destination_longitude: 8.6821,
        destination_country: 'DE',
        distance_km: 393,
        pickup_date_from: 2.days.from_now
      }
    }

    request = TransportRequest.last
    # Quote generation happens in controller - check redirect message (German locale)
    assert_match(/Angebot|erstellt/i, flash[:notice] || flash[:alert])
  end

  test "create with loading_meters mode" do
    sign_in @customer

    assert_difference('TransportRequest.count', 1) do
      post customer_transport_requests_url, params: {
        transport_request: {
          shipping_mode: 'loading_meters',
          loading_meters: 10.5,
          total_height_cm: 260,
          total_weight_kg: 15000,
          start_address: 'Hamburg, Germany',
          start_latitude: 53.5511,
          start_longitude: 9.9937,
          start_country: 'DE',
          destination_address: 'Frankfurt, Germany',
          destination_latitude: 50.1109,
          destination_longitude: 8.6821,
          destination_country: 'DE',
          pickup_date_from: 2.days.from_now
        }
      }
    end

    request = TransportRequest.last
    assert_equal 'loading_meters', request.shipping_mode
    assert_equal 10.5, request.loading_meters
    assert_equal 0, request.package_items.count
  end

  test "create with invalid data shows errors" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        # Missing required start_address
        destination_address: 'Frankfurt, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    assert_response :unprocessable_entity
    assert_template :new
    request = assigns(:transport_request)
    assert_includes request.errors[:start_address], "can't be blank"
  end

  test "create permits all customer params including detailed addresses" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Hamburg, Germany',
        start_latitude: 53.5511,
        start_longitude: 9.9937,
        start_country: 'DE',
        start_company_name: 'ACME Corp',
        start_street: 'Hauptstrasse',
        start_street_number: '42',
        start_city: 'Hamburg',
        start_postal_code: '20095',
        start_notes: 'Ring doorbell',
        destination_address: 'Frankfurt, Germany',
        destination_latitude: 50.1109,
        destination_longitude: 8.6821,
        destination_country: 'DE',
        destination_company_name: 'XYZ GmbH',
        destination_street: 'Bahnhofstrasse',
        destination_street_number: '10',
        destination_city: 'Frankfurt',
        destination_postal_code: '60329',
        destination_notes: 'Loading dock B',
        pickup_date_from: 2.days.from_now,
        pickup_notes: 'Available 8-12',
        delivery_date_from: 3.days.from_now,
        delivery_notes: 'Call ahead',
        requires_liftgate: true,
        requires_gps_tracking: true,
        driver_language: 'de',
        package_items_attributes: [
          { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
        ]
      }
    }

    request = TransportRequest.last
    assert_equal 'ACME Corp', request.start_company_name
    assert_equal 'Hauptstrasse', request.start_street
    assert_equal '42', request.start_street_number
    assert_equal 'Hamburg', request.start_city
    assert_equal '20095', request.start_postal_code
    assert_equal 'Ring doorbell', request.start_notes
    assert_equal 'XYZ GmbH', request.destination_company_name
    assert_equal 'Loading dock B', request.destination_notes
    assert_equal true, request.requires_liftgate
    assert_equal true, request.requires_gps_tracking
    assert_equal 'de', request.driver_language
  end

  # ========== EDIT ACTION ==========

  test "edit loads existing request" do
    sign_in @customer
    get edit_customer_transport_request_url(@transport_request)

    assert_response :success
    assert_equal @transport_request, assigns(:transport_request)
  end

  # ========== UPDATE ACTION ==========

  test "update changes basic fields" do
    sign_in @customer

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        pickup_date_from: 5.days.from_now,
        delivery_date_from: 6.days.from_now,
        requires_liftgate: true
      }
    }

    assert_redirected_to customer_transport_request_path(@transport_request)
    assert_equal "Request updated successfully.", flash[:notice]

    @transport_request.reload
    assert_equal true, @transport_request.requires_liftgate
  end

  test "update adds new package_items" do
    sign_in @customer

    assert_difference('@transport_request.package_items.count', 1) do
      patch customer_transport_request_url(@transport_request), params: {
        transport_request: {
          package_items_attributes: [
            {
              package_type: 'half_pallet',
              quantity: 3,
              length_cm: 60,
              width_cm: 80,
              height_cm: 144,
              weight_kg: 150
            }
          ]
        }
      }
      @transport_request.reload
    end

    new_item = @transport_request.package_items.find_by(package_type: 'half_pallet')
    assert_not_nil new_item
    assert_equal 3, new_item.quantity
  end

  test "update removes package_items via _destroy" do
    sign_in @customer
    package_item = @transport_request.package_items.first

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          { id: package_item.id, _destroy: '1' }
        ]
      }
    }

    assert_redirected_to customer_transport_request_path(@transport_request)
    assert_not PackageItem.exists?(package_item.id)
  end

  test "update with invalid data shows errors" do
    sign_in @customer

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        start_address: ''  # Invalid - required field
      }
    }

    assert_response :unprocessable_entity
    assert_template :edit
    request = assigns(:transport_request)
    assert_includes request.errors[:start_address], "can't be blank"
  end

  # ========== CANCEL ACTION ==========

  test "cancel updates status to cancelled" do
    sign_in @customer

    post cancel_customer_transport_request_url(@transport_request)

    @transport_request.reload
    assert_equal 'cancelled', @transport_request.status
    assert_redirected_to customer_transport_request_path(@transport_request)
    assert_equal "Request cancelled successfully.", flash[:notice]
  end


  # ========== STRONG PARAMETERS ==========

  test "create filters unpermitted attributes" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        status: 'delivered',  # Unpermitted - should be ignored
        matched_carrier_id: 999,  # Unpermitted - should be ignored
        start_address: 'Hamburg, Germany',
        start_latitude: 53.5511,
        start_longitude: 9.9937,
        destination_address: 'Frankfurt, Germany',
        destination_latitude: 50.1109,
        destination_longitude: 8.6821,
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
        ]
      }
    }

    request = TransportRequest.last
    assert_equal 'new', request.status  # Set by controller, not params
    assert_nil request.matched_carrier_id
  end

  test "create permits package_items_attributes with _destroy" do
    sign_in @customer

    # Verify _destroy is permitted in update
    package_item = @transport_request.package_items.first

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          { id: package_item.id, _destroy: '1' }
        ]
      }
    }

    assert_not PackageItem.exists?(package_item.id)
  end

  # ========== EDGE CASES ==========

  test "switching modes on update clears package_items" do
    sign_in @customer
    package_item_ids = @transport_request.package_items.pluck(:id)

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 12.0,
        total_height_cm: 260,
        total_weight_kg: 18000,
        package_items_attributes: package_item_ids.map { |id| { id: id, _destroy: '1' } }
      }
    }

    @transport_request.reload
    assert_equal 'loading_meters', @transport_request.shipping_mode
    assert_equal 0, @transport_request.package_items.count
  end

  test "create without coordinates skips distance calculation" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Hamburg, Germany',
        # No coordinates provided
        destination_address: 'Frankfurt, Germany',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
        ]
      }
    }

    request = TransportRequest.last
    assert_nil request.distance_km
  end

  test "create sets user to current_user" do
    sign_in @customer

    post customer_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Hamburg, Germany',
        start_latitude: 53.5511,
        start_longitude: 9.9937,
        destination_address: 'Frankfurt, Germany',
        destination_latitude: 50.1109,
        destination_longitude: 8.6821,
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
        ]
      }
    }

    request = TransportRequest.last
    assert_equal @customer, request.user
  end

  test "update does not allow changing user" do
    sign_in @customer

    patch customer_transport_request_url(@transport_request), params: {
      transport_request: {
        user_id: @customer_two.id  # Attempt to change user
      }
    }

    @transport_request.reload
    assert_equal @customer, @transport_request.user  # Should remain unchanged
  end
end
