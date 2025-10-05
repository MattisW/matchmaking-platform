require "test_helper"

class Admin::CarrierRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_carrier_requests_index_url
    assert_response :success
  end

  test "should get show" do
    get admin_carrier_requests_show_url
    assert_response :success
  end

  test "should get accept" do
    get admin_carrier_requests_accept_url
    assert_response :success
  end

  test "should get reject" do
    get admin_carrier_requests_reject_url
    assert_response :success
  end
end
