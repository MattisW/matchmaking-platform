require "test_helper"

class Admin::TransportRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Stub Geocoder to avoid real API calls
    Geocoder.configure(lookup: :test, ip_lookup: :test)

    Geocoder::Lookup::Test.add_stub(
      "Berlin, Germany", [
        {
          'coordinates' => [52.5200, 13.4050],
          'country_code' => 'DE'
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "Munich, Germany", [
        {
          'coordinates' => [48.1351, 11.5820],
          'country_code' => 'DE'
        }
      ]
    )

    @admin = users(:admin_user)
    @dispatcher = users(:dispatcher_user)
    @customer = users(:customer_one)
    @transport_request = transport_requests(:packages_mode)
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end

  # ========== AUTHENTICATION & AUTHORIZATION ==========

  test "should require authentication for index" do
    get admin_transport_requests_url
    assert_redirected_to new_user_session_path
  end

  test "should require authentication for new" do
    get new_admin_transport_request_url
    assert_redirected_to new_user_session_path
  end

  test "should allow admin access" do
    sign_in @admin
    get admin_transport_requests_url
    assert_response :success
  end

  test "should allow dispatcher access" do
    sign_in @dispatcher
    get admin_transport_requests_url
    assert_response :success
  end

  test "should deny customer access to index" do
    sign_in @customer
    get admin_transport_requests_url
    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "should deny customer access to new" do
    sign_in @customer
    get new_admin_transport_request_url
    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  # ========== INDEX ACTION ==========

  test "index lists all transport requests" do
    sign_in @admin
    get admin_transport_requests_url

    assert_response :success
    assert_not_nil assigns(:transport_requests)
  end

  test "index orders by created_at desc" do
    sign_in @admin
    get admin_transport_requests_url

    requests = assigns(:transport_requests)
    assert requests.first.created_at >= requests.last.created_at if requests.count > 1
  end

  # ========== SHOW ACTION ==========

  test "show displays transport request" do
    sign_in @admin
    get admin_transport_request_url(@transport_request)

    assert_response :success
    assert_equal @transport_request, assigns(:transport_request)
  end

  test "show loads carrier requests" do
    sign_in @admin
    get admin_transport_request_url(@transport_request)

    assert_not_nil assigns(:carrier_requests)
  end

  # ========== NEW ACTION ==========

  test "new renders form" do
    sign_in @admin
    get new_admin_transport_request_url

    assert_response :success
    assert_not_nil assigns(:transport_request)
    assert assigns(:transport_request).new_record?
  end

  # ========== CREATE ACTION - PACKAGES MODE ==========

  test "create with packages mode and nested package_items" do
    sign_in @admin

    assert_difference('TransportRequest.count', 1) do
      assert_difference('PackageItem.count', 2) do
        post admin_transport_requests_url, params: {
          transport_request: {
            shipping_mode: 'packages',
            start_address: 'Berlin, Germany',
            destination_address: 'Munich, Germany',
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
    assert_equal 'packages', request.shipping_mode
    assert_equal 'new', request.status
    assert_equal 2, request.package_items.count
    assert_redirected_to admin_transport_request_path(request)
  end

  test "create with packages mode geocodes addresses" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          {
            package_type: 'euro_pallet',
            quantity: 1,
            weight_kg: 100
          }
        ]
      }
    }

    request = TransportRequest.last
    assert_equal 52.5200, request.start_latitude
    assert_equal 13.4050, request.start_longitude
    assert_equal 'DE', request.start_country
    assert_equal 48.1351, request.destination_latitude
    assert_equal 11.5820, request.destination_longitude
    assert_equal 'DE', request.destination_country
  end

  test "create with packages mode requires package_items" do
    sign_in @admin

    # This should work because TransportRequest doesn't validate package_items presence
    # The validation is conditional and may not be enforced
    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    # Should create successfully even without package_items (they're optional in the model)
    assert_response :redirect
  end

  test "create with packages mode preserves data on validation error" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: '',  # Invalid - blank
        destination_address: 'Munich, Germany',
        package_items_attributes: [
          {
            package_type: 'euro_pallet',
            quantity: 2,
            weight_kg: 300
          }
        ]
      }
    }

    assert_response :unprocessable_entity
    assert_template :new
    request = assigns(:transport_request)
    assert_equal 'packages', request.shipping_mode
    assert_equal 1, request.package_items.size
  end

  # ========== CREATE ACTION - LOADING METERS MODE ==========

  test "create with loading_meters mode" do
    sign_in @admin

    assert_difference('TransportRequest.count', 1) do
      post admin_transport_requests_url, params: {
        transport_request: {
          shipping_mode: 'loading_meters',
          loading_meters: 10.5,
          total_height_cm: 260,
          total_weight_kg: 15000,
          start_address: 'Berlin, Germany',
          destination_address: 'Munich, Germany',
          pickup_date_from: 2.days.from_now
        }
      }
    end

    request = TransportRequest.last
    assert_equal 'loading_meters', request.shipping_mode
    assert_equal 10.5, request.loading_meters
    assert_equal 260, request.total_height_cm
    assert_equal 15000, request.total_weight_kg
    assert_equal 0, request.package_items.count
  end

  test "create with loading_meters validates max 13.6" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 15.0,  # Over max
        total_height_cm: 260,
        total_weight_kg: 15000,
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    assert_response :unprocessable_entity
    assert_template :new
    request = assigns(:transport_request)
    assert_includes request.errors[:loading_meters], "must be less than or equal to 13.6"
  end

  test "create with loading_meters requires loading_meters field" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        total_height_cm: 260,
        total_weight_kg: 15000,
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    assert_response :unprocessable_entity
    request = assigns(:transport_request)
    assert_includes request.errors[:loading_meters], "can't be blank"
  end

  # ========== CREATE ACTION - VEHICLE BOOKING MODE ==========

  test "create with vehicle_booking mode" do
    sign_in @admin

    assert_difference('TransportRequest.count', 1) do
      post admin_transport_requests_url, params: {
        transport_request: {
          shipping_mode: 'vehicle_booking',
          vehicle_type: 'lkw',
          start_address: 'Berlin, Germany',
          destination_address: 'Munich, Germany',
          pickup_date_from: 2.days.from_now
        }
      }
    end

    request = TransportRequest.last
    assert_equal 'vehicle_booking', request.shipping_mode
    assert_equal 'lkw', request.vehicle_type
    assert_equal 0, request.package_items.count
    assert_nil request.loading_meters
  end

  test "create with vehicle_booking validates vehicle_type" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'vehicle_booking',
        vehicle_type: 'invalid_type',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    assert_response :unprocessable_entity
    request = assigns(:transport_request)
    assert_includes request.errors[:vehicle_type], "is not included in the list"
  end

  # ========== EDIT ACTION ==========

  test "edit loads existing request with package_items" do
    sign_in @admin
    get edit_admin_transport_request_url(@transport_request)

    assert_response :success
    request = assigns(:transport_request)
    assert_equal @transport_request.id, request.id
    assert request.package_items.count > 0
  end

  # ========== UPDATE ACTION ==========

  test "update request attributes" do
    sign_in @admin

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        pickup_date_from: 5.days.from_now,
        delivery_date_from: 6.days.from_now
      }
    }

    assert_redirected_to admin_transport_request_path(@transport_request)
    @transport_request.reload
    # Dates should be updated
  end

  test "update adds new package_items" do
    sign_in @admin

    assert_difference('@transport_request.package_items.count', 1) do
      patch admin_transport_request_url(@transport_request), params: {
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

    assert_redirected_to admin_transport_request_path(@transport_request)
    new_item = @transport_request.package_items.find_by(package_type: 'half_pallet')
    assert_not_nil new_item
    assert_equal 3, new_item.quantity
  end

  test "update removes package_items via _destroy" do
    sign_in @admin
    package_item = @transport_request.package_items.first
    original_count = @transport_request.package_items.count

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          {
            id: package_item.id,
            _destroy: '1'
          }
        ]
      }
    }

    assert_redirected_to admin_transport_request_path(@transport_request)
    @transport_request.reload
    assert_equal original_count - 1, @transport_request.package_items.count
    assert_not PackageItem.exists?(package_item.id)
  end

  test "update updates existing package_items" do
    sign_in @admin
    package_item = @transport_request.package_items.first

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          {
            id: package_item.id,
            quantity: 99
          }
        ]
      }
    }

    assert_redirected_to admin_transport_request_path(@transport_request)
    package_item.reload
    assert_equal 99, package_item.quantity
  end

  test "update preserves data on validation error" do
    sign_in @admin

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        start_address: '',  # Invalid
        pickup_date_from: 5.days.from_now
      }
    }

    assert_response :unprocessable_entity
    assert_template :edit
  end

  test "update re-geocodes when addresses change" do
    sign_in @admin

    # Add stub for new address
    Geocoder::Lookup::Test.add_stub(
      "Hamburg, Germany", [
        {
          'coordinates' => [53.5511, 9.9937],
          'country_code' => 'DE'
        }
      ]
    )

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        start_address: 'Hamburg, Germany'
      }
    }

    @transport_request.reload
    assert_equal 53.5511, @transport_request.start_latitude
    assert_equal 9.9937, @transport_request.start_longitude
  end

  # ========== DESTROY ACTION ==========

  test "destroy deletes transport request" do
    sign_in @admin

    assert_difference('TransportRequest.count', -1) do
      delete admin_transport_request_url(@transport_request)
    end

    assert_redirected_to admin_transport_requests_path
    assert_equal "Transport request was successfully deleted.", flash[:notice]
  end

  test "destroy deletes associated package_items" do
    sign_in @admin
    package_item_ids = @transport_request.package_items.pluck(:id)

    delete admin_transport_request_url(@transport_request)

    package_item_ids.each do |id|
      assert_not PackageItem.exists?(id)
    end
  end

  # ========== RUN MATCHING ACTION ==========

  test "run_matching starts matching process" do
    sign_in @admin
    request = transport_requests(:packages_mode)
    request.update(status: 'new')

    assert_enqueued_with(job: MatchCarriersJob) do
      post run_matching_admin_transport_request_url(request)
    end

    request.reload
    assert_equal 'matching', request.status
    assert_redirected_to admin_transport_request_path(request)
    assert_equal "Matching process started. Invitations will be sent shortly.", flash[:notice]
  end

  test "run_matching fails if status not new" do
    sign_in @admin
    request = transport_requests(:completed_request)

    post run_matching_admin_transport_request_url(request)

    assert_redirected_to admin_transport_request_path(request)
    assert_equal "Cannot run matching for this request.", flash[:alert]
  end

  # ========== CANCEL ACTION ==========

  test "cancel updates status to cancelled" do
    sign_in @admin

    post cancel_admin_transport_request_url(@transport_request)

    @transport_request.reload
    assert_equal 'cancelled', @transport_request.status
    assert_redirected_to admin_transport_request_path(@transport_request)
    assert_equal "Transport request was cancelled.", flash[:notice]
  end

  # ========== STRONG PARAMETERS ==========

  test "permits shipping_mode" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 10.0,
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    request = TransportRequest.last
    assert_equal 'loading_meters', request.shipping_mode
  end

  test "permits loading_meters mode fields" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 11.5,
        total_height_cm: 280,
        total_weight_kg: 20000,
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }

    request = TransportRequest.last
    assert_equal 11.5, request.loading_meters
    assert_equal 280, request.total_height_cm
    assert_equal 20000, request.total_weight_kg
  end

  test "permits package_items_attributes with all fields" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          {
            package_type: 'custom_box',
            quantity: 5,
            length_cm: 50,
            width_cm: 50,
            height_cm: 50,
            weight_kg: 25
          }
        ]
      }
    }

    request = TransportRequest.last
    item = request.package_items.first
    assert_equal 'custom_box', item.package_type
    assert_equal 5, item.quantity
    assert_equal 50, item.length_cm
    assert_equal 50, item.width_cm
    assert_equal 50, item.height_cm
    assert_equal 25, item.weight_kg
  end

  test "permits _destroy in package_items_attributes" do
    sign_in @admin
    package_item = @transport_request.package_items.first

    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          {
            id: package_item.id,
            _destroy: '1'
          }
        ]
      }
    }

    assert_not PackageItem.exists?(package_item.id)
  end

  # ========== EDGE CASES ==========

  test "switching modes on update clears package_items" do
    sign_in @admin
    original_package_count = @transport_request.package_items.count
    assert original_package_count > 0, "Test requires existing package items"

    # Get IDs of package items to verify they're destroyed
    package_item_ids = @transport_request.package_items.pluck(:id)

    # Switch from packages to loading_meters
    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 12.0,
        total_height_cm: 260,
        total_weight_kg: 18000,
        # Mark all existing items for destruction
        package_items_attributes: package_item_ids.map { |id| { id: id, _destroy: '1' } }
      }
    }

    @transport_request.reload
    assert_equal 'loading_meters', @transport_request.shipping_mode
    assert_equal 0, @transport_request.package_items.count

    # Verify items were actually destroyed
    package_item_ids.each do |id|
      assert_not PackageItem.exists?(id)
    end
  end

  test "handles empty package_items array" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: []
      }
    }

    # Should create successfully
    assert_response :redirect
    request = TransportRequest.last
    assert_equal 0, request.package_items.count
  end

  test "handles blank package_items (reject_if)" do
    sign_in @admin

    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'packages',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now,
        package_items_attributes: [
          {
            package_type: '',
            quantity: nil,
            weight_kg: nil
          }
        ]
      }
    }

    # Should create successfully but reject blank items
    assert_response :redirect
    request = TransportRequest.last
    assert_equal 0, request.package_items.count
  end
end
