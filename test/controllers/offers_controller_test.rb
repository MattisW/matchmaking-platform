require "test_helper"

class OffersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @carrier_request = carrier_requests(:packages_berlin_express)  # status: sent
    @transport_request = @carrier_request.transport_request
    @carrier = @carrier_request.carrier
  end

  # ========== NO AUTHENTICATION REQUIRED ==========

  test "show action accessible without login" do
    get offer_path(@carrier_request)
    assert_response :success
  end

  test "submit_offer accessible without login" do
    post submit_offer_offer_path(@carrier_request), params: {
      carrier_request: {
        offered_price: 500.00,
        offered_delivery_date: 3.days.from_now,
        transport_type: 'standard',
        notes: 'Available for pickup'
      }
    }
    assert_redirected_to offer_path(@carrier_request)
  end

  # ========== SHOW ACTION ==========

  test "show displays offer form with carrier_request" do
    get offer_path(@carrier_request)

    assert_response :success
    assert_equal @carrier_request, assigns(:carrier_request)
    assert_equal @transport_request, assigns(:transport_request)
    assert_equal @carrier, assigns(:carrier)
  end

  test "show loads transport_request and carrier associations" do
    get offer_path(@carrier_request)

    carrier_request = assigns(:carrier_request)
    assert_not_nil carrier_request
    assert_not_nil assigns(:transport_request)
    assert_not_nil assigns(:carrier)
  end

  # ========== SUBMIT OFFER ACTION ==========

  test "submit_offer with valid data updates carrier_request" do
    post submit_offer_offer_path(@carrier_request), params: {
      carrier_request: {
        offered_price: 450.00,
        offered_delivery_date: 2.days.from_now.to_s,
        transport_type: 'express',
        vehicle_type: 'transporter',
        driver_language: 'de',
        notes: 'Can deliver earlier if needed'
      }
    }

    @carrier_request.reload
    assert_equal 450.00, @carrier_request.offered_price
    assert_equal 'express', @carrier_request.transport_type
    assert_equal 'transporter', @carrier_request.vehicle_type
    assert_equal 'de', @carrier_request.driver_language
    assert_equal 'Can deliver earlier if needed', @carrier_request.notes
  end

  test "submit_offer updates status to offered" do
    post submit_offer_offer_path(@carrier_request), params: {
      carrier_request: {
        offered_price: 500.00,
        offered_delivery_date: 3.days.from_now
      }
    }

    @carrier_request.reload
    assert_equal 'offered', @carrier_request.status
  end

  test "submit_offer sets response_date to current time" do
    freeze_time do
      post submit_offer_offer_path(@carrier_request), params: {
        carrier_request: {
          offered_price: 500.00,
          offered_delivery_date: 3.days.from_now
        }
      }

      @carrier_request.reload
      assert_not_nil @carrier_request.response_date
      assert_in_delta Time.current, @carrier_request.response_date, 1.second
    end
  end

end
