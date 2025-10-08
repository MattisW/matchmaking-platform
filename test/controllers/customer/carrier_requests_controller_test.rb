require "test_helper"

module Customer
  class CarrierRequestsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @customer = users(:customer_one)
      @customer_two = users(:customer_two)
      @admin = users(:admin_user)

      # Transport request belonging to customer_one
      @transport_request = transport_requests(:packages_mode)
      @carrier_one = carriers(:munich_freight_services)
      @carrier_two = carriers(:hamburg_cargo_solutions)

      # Carrier requests for this transport_request
      @carrier_request_one = carrier_requests(:packages_munich_freight)  # status: offered
      @carrier_request_two = carrier_requests(:packages_berlin_express)  # status: sent
    end

    # ========== AUTHENTICATION & AUTHORIZATION ==========

    test "should require authentication for accept" do
      post accept_customer_transport_request_carrier_request_path(@transport_request, @carrier_request_one)
      assert_redirected_to new_user_session_path
    end

    test "should require authentication for reject" do
      post reject_customer_transport_request_carrier_request_path(@transport_request, @carrier_request_one)
      assert_redirected_to new_user_session_path
    end


    test "should deny admin access to customer area for accept" do
      sign_in @admin

      @carrier_request_one.update(status: 'offered')
      post accept_customer_transport_request_carrier_request_path(@transport_request, @carrier_request_one)
      assert_redirected_to root_path
    end

    # ========== ACCEPT ACTION ==========

    test "accept marks carrier_request as won" do
      sign_in @customer

      @carrier_request_one.update(status: 'offered')

      post accept_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      @carrier_request_one.reload
      assert_equal 'won', @carrier_request_one.status
    end

    test "accept rejects other offers for same transport_request" do
      sign_in @customer

      # Create two offered carrier_requests
      @carrier_request_one.update(status: 'offered', offered_price: 500)
      other_carrier_request = @transport_request.carrier_requests.create!(
        carrier: @carrier_two,
        status: 'offered',
        offered_price: 600
      )

      post accept_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      other_carrier_request.reload
      assert_equal 'rejected', other_carrier_request.status
    end

    test "accept updates transport_request status and matched_carrier_id" do
      sign_in @customer

      @carrier_request_one.update(status: 'offered')

      post accept_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      @transport_request.reload
      assert_equal 'matched', @transport_request.status
      assert_equal @carrier_request_one.carrier_id, @transport_request.matched_carrier_id
    end

    # ========== REJECT ACTION ==========

    test "reject marks carrier_request as rejected" do
      sign_in @customer

      @carrier_request_one.update(status: 'offered')

      post reject_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      @carrier_request_one.reload
      assert_equal 'rejected', @carrier_request_one.status
    end

    test "reject redirects to transport_request with notice" do
      sign_in @customer

      @carrier_request_one.update(status: 'offered')

      post reject_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      assert_redirected_to customer_transport_request_path(@transport_request)
      assert_equal "Offer rejected.", flash[:notice]
    end

    test "accept redirects to transport_request with notice" do
      sign_in @customer

      @carrier_request_one.update(status: 'offered')

      post accept_customer_transport_request_carrier_request_url(@transport_request, @carrier_request_one)

      assert_redirected_to customer_transport_request_path(@transport_request)
      assert_equal "Offer accepted! Carrier has been notified.", flash[:notice]
    end
  end
end
