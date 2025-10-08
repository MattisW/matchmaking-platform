require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @customer = users(:customer_one)
  end

  # ========== AUTHENTICATION & AUTHORIZATION ==========

  test "should require authentication for index" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "should allow admin access" do
    sign_in @admin
    get root_path
    assert_response :success
  end

  test "should route customers to their own dashboard" do
    sign_in @customer
    get root_path
    # Customers see their own dashboard (customer_root_path), not admin dashboard
    assert_response :success
  end

  # ========== INDEX ACTION - STATISTICS ==========

  test "index calculates total_requests correctly" do
    sign_in @admin
    get root_path

    total_requests = assigns(:total_requests)
    assert_not_nil total_requests
    assert_equal TransportRequest.count, total_requests
  end

  test "index calculates active_requests using scope" do
    sign_in @admin
    get root_path

    active_requests = assigns(:active_requests)
    assert_not_nil active_requests

    # Verify it uses the active scope
    expected_count = TransportRequest.active.count
    assert_equal expected_count, active_requests
  end

  test "index calculates total_carriers using active scope" do
    sign_in @admin
    get root_path

    total_carriers = assigns(:total_carriers)
    assert_not_nil total_carriers

    # Verify it uses the active scope (non-blacklisted carriers)
    expected_count = Carrier.active.count
    assert_equal expected_count, total_carriers
  end

  test "index calculates pending_offers with status offered" do
    sign_in @admin
    get root_path

    pending_offers = assigns(:pending_offers)
    assert_not_nil pending_offers

    # Verify it counts only offered status
    expected_count = CarrierRequest.where(status: "offered").count
    assert_equal expected_count, pending_offers
  end

  test "index loads recent_requests ordered and limited to 10" do
    sign_in @admin
    get root_path

    recent_requests = assigns(:recent_requests)
    assert_not_nil recent_requests

    # Verify limit
    assert recent_requests.count <= 10

    # Verify ordering (most recent first)
    if recent_requests.count > 1
      assert recent_requests.first.created_at >= recent_requests.last.created_at
    end
  end
end
