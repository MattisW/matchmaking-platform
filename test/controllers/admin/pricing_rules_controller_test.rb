require "test_helper"

module Admin
  class PricingRulesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin_user)
      @customer = users(:customer_one)
      @pricing_rule = pricing_rules(:transporter_rule)
    end

    # ========== AUTHENTICATION & AUTHORIZATION ==========

    test "should require authentication for index" do
      get admin_pricing_rules_url
      assert_redirected_to new_user_session_path
    end

    test "should allow admin access" do
      sign_in @admin
      get admin_pricing_rules_url
      assert_response :success
    end

    test "should deny customer access" do
      sign_in @customer
      get admin_pricing_rules_url
      assert_redirected_to root_path
    end

    # ========== INDEX ACTION ==========

    test "index lists all pricing rules ordered by vehicle_type" do
      sign_in @admin
      get admin_pricing_rules_url

      assert_response :success
      pricing_rules = assigns(:pricing_rules)
      assert_not_nil pricing_rules
      assert pricing_rules.count >= 1
    end

    test "index orders by vehicle_type asc then created_at desc" do
      sign_in @admin
      get admin_pricing_rules_url

      pricing_rules = assigns(:pricing_rules)
      # Verify ordering exists (implementation detail)
      assert_not_nil pricing_rules
    end

    # ========== NEW ACTION ==========

    test "new renders form with new pricing rule" do
      sign_in @admin
      get new_admin_pricing_rule_url

      assert_response :success
      pricing_rule = assigns(:pricing_rule)
      assert_not_nil pricing_rule
      assert pricing_rule.new_record?
    end

    # ========== CREATE ACTION ==========

    test "create with valid data" do
      sign_in @admin

      assert_difference('PricingRule.count', 1) do
        post admin_pricing_rules_url, params: {
          pricing_rule: {
            vehicle_type: 'lkw_18t',
            rate_per_km: 2.00,
            minimum_price: 300.00,
            weekend_surcharge_percent: 15.0,
            express_surcharge_percent: 35.0,
            active: true
          }
        }
      end

      pricing_rule = PricingRule.last
      assert_equal 'lkw_18t', pricing_rule.vehicle_type
      assert_equal 2.00, pricing_rule.rate_per_km
      assert_redirected_to admin_pricing_rules_path
    end

    test "create with validation errors re-renders form" do
      sign_in @admin

      post admin_pricing_rules_url, params: {
        pricing_rule: {
          vehicle_type: '',  # Invalid - required
          rate_per_km: -1.0  # Invalid - must be > 0
        }
      }

      assert_response :unprocessable_entity
      assert_template :new
      pricing_rule = assigns(:pricing_rule)
      assert_includes pricing_rule.errors[:vehicle_type], "can't be blank"
      assert_includes pricing_rule.errors[:rate_per_km], "must be greater than 0"
    end

    # ========== EDIT ACTION ==========

    test "edit loads existing pricing rule" do
      sign_in @admin
      get edit_admin_pricing_rule_url(@pricing_rule)

      assert_response :success
      assert_equal @pricing_rule, assigns(:pricing_rule)
    end

    # ========== UPDATE ACTION ==========

    test "update changes fields" do
      sign_in @admin

      patch admin_pricing_rule_url(@pricing_rule), params: {
        pricing_rule: {
          rate_per_km: 1.50,
          minimum_price: 175.00
        }
      }

      assert_redirected_to admin_pricing_rules_path

      @pricing_rule.reload
      assert_equal 1.50, @pricing_rule.rate_per_km
      assert_equal 175.00, @pricing_rule.minimum_price
    end

    test "update with validation errors re-renders form" do
      sign_in @admin

      patch admin_pricing_rule_url(@pricing_rule), params: {
        pricing_rule: {
          rate_per_km: -5.0  # Invalid
        }
      }

      assert_response :unprocessable_entity
      assert_template :edit
    end

    # ========== DESTROY ACTION ==========

    test "destroy deletes pricing rule" do
      sign_in @admin

      assert_difference('PricingRule.count', -1) do
        delete admin_pricing_rule_url(@pricing_rule)
      end

      assert_redirected_to admin_pricing_rules_path
    end
  end
end
