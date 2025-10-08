require "test_helper"

class TransportRequestTest < ActiveSupport::TestCase
  # ========== ASSOCIATIONS ==========

  test "should belong to user" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :user
    assert_instance_of User, transport_request.user
  end

  test "should belong to matched_carrier optionally" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :matched_carrier
    assert_nil transport_request.matched_carrier

    # Test with a matched carrier
    carrier = carriers(:german_logistics_gmbh)
    transport_request.matched_carrier = carrier
    assert_equal carrier, transport_request.matched_carrier
  end

  test "should have many carrier_requests" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :carrier_requests
    assert transport_request.carrier_requests.count > 0
  end

  test "should have many carriers through carrier_requests" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :carriers
    assert transport_request.carriers.count > 0
  end

  test "should have many package_items" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :package_items
    assert transport_request.package_items.count > 0
  end

  test "should have one quote" do
    transport_request = transport_requests(:packages_mode)
    assert_respond_to transport_request, :quote
  end

  test "should destroy dependent carrier_requests when destroyed" do
    transport_request = transport_requests(:packages_mode)
    carrier_request_ids = transport_request.carrier_requests.pluck(:id)

    transport_request.destroy

    carrier_request_ids.each do |id|
      assert_nil CarrierRequest.find_by(id: id)
    end
  end

  test "should destroy dependent package_items when destroyed" do
    transport_request = transport_requests(:packages_mode)
    package_item_ids = transport_request.package_items.pluck(:id)

    transport_request.destroy

    package_item_ids.each do |id|
      assert_nil PackageItem.find_by(id: id)
    end
  end

  # ========== VALIDATIONS - REQUIRED FIELDS ==========

  test "should require start_address" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:start_address], "can't be blank"
  end

  test "should require destination_address" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      pickup_date_from: 1.day.from_now
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:destination_address], "can't be blank"
  end

  test "should require pickup_date_from" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany"
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:pickup_date_from], "can't be blank"
  end

  # ========== VALIDATIONS - INCLUSION ==========

  test "vehicle_type must be valid if present" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      vehicle_type: "invalid_type"
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:vehicle_type], "is not included in the list"
  end

  test "vehicle_type can be transporter, lkw, or either" do
    %w[transporter lkw either].each do |vehicle_type|
      transport_request = TransportRequest.new(
        user: users(:customer_one),
        start_address: "Berlin, Germany",
        destination_address: "Munich, Germany",
        pickup_date_from: 1.day.from_now,
        vehicle_type: vehicle_type
      )

      assert transport_request.valid?, "#{vehicle_type} should be valid"
    end
  end

  test "status must be valid if present" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      status: "invalid_status"
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:status], "is not included in the list"
  end

  test "shipping_mode must be valid if present" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "invalid_mode"
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:shipping_mode], "is not included in the list"
  end

  test "shipping_mode can be packages, loading_meters, or vehicle_booking" do
    %w[packages loading_meters vehicle_booking].each do |mode|
      transport_request = TransportRequest.new(
        user: users(:customer_one),
        start_address: "Berlin, Germany",
        destination_address: "Munich, Germany",
        pickup_date_from: 1.day.from_now,
        shipping_mode: mode,
        loading_meters: (mode == 'loading_meters' ? 10.5 : nil)
      )

      assert transport_request.valid?, "#{mode} should be valid"
    end
  end

  # ========== VALIDATIONS - CONDITIONAL ==========

  test "loading_meters required when shipping_mode is loading_meters" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "loading_meters"
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:loading_meters], "can't be blank"
  end

  test "loading_meters must be greater than zero" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "loading_meters",
      loading_meters: 0
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:loading_meters], "must be greater than 0"
  end

  test "loading_meters must be less than or equal to 13.6" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "loading_meters",
      loading_meters: 14.0
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:loading_meters], "must be less than or equal to 13.6"
  end

  test "loading_meters not required when shipping_mode is packages" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "packages"
    )

    assert transport_request.valid?
  end

  # ========== CUSTOM VALIDATIONS ==========

  test "delivery_date_from must be after pickup_date_from" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 2.days.from_now,
      delivery_date_from: 1.day.from_now
    )

    assert_not transport_request.valid?
    assert_includes transport_request.errors[:delivery_date_from], "must be after pickup date"
  end

  test "delivery_date_from can be same as pickup_date_from" do
    date = 2.days.from_now
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: date,
      delivery_date_from: date
    )

    assert transport_request.valid?
  end

  # ========== SCOPES ==========

  test "active scope excludes cancelled and delivered" do
    active_requests = TransportRequest.active

    assert_not active_requests.include?(transport_requests(:completed_request))
    assert active_requests.include?(transport_requests(:packages_mode))
  end

  test "recent scope orders by created_at desc" do
    recent_requests = TransportRequest.recent.limit(2)

    assert recent_requests.first.created_at >= recent_requests.last.created_at
  end

  test "pending_matching scope returns only new requests" do
    pending = TransportRequest.pending_matching

    pending.each do |request|
      assert_equal "new", request.status
    end
  end

  test "matched scope returns only matched requests" do
    # First, create a matched request
    transport_request = transport_requests(:packages_mode)
    transport_request.update(status: "matched")

    matched = TransportRequest.matched

    assert matched.include?(transport_request)
    matched.each do |request|
      assert_equal "matched", request.status
    end
  end

  # ========== PACKAGE CALCULATIONS ==========

  test "total_package_weight sums all package items" do
    transport_request = transport_requests(:packages_mode)

    expected_weight = transport_request.package_items.sum(&:total_weight)
    assert_equal expected_weight, transport_request.total_package_weight
  end

  test "total_package_count sums all package quantities" do
    transport_request = transport_requests(:packages_mode)

    expected_count = transport_request.package_items.sum(:quantity)
    assert_equal expected_count, transport_request.total_package_count
  end

  # ========== SHIPPING MODES ==========

  test "can create request in packages mode" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "packages"
    )

    assert transport_request.valid?
  end

  test "can create request in loading_meters mode" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "loading_meters",
      loading_meters: 10.5,
      total_height_cm: 260,
      total_weight_kg: 15000
    )

    assert transport_request.valid?
    assert transport_request.save
  end

  test "can create request in vehicle_booking mode" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "vehicle_booking",
      vehicle_type: "lkw"
    )

    assert transport_request.valid?
    assert transport_request.save
  end

  # ========== NESTED ATTRIBUTES ==========

  test "can create package_items through nested attributes" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "packages",
      package_items_attributes: [
        {
          package_type: "euro_pallet",
          quantity: 2,
          length_cm: 120,
          width_cm: 80,
          height_cm: 144,
          weight_kg: 300
        }
      ]
    )

    assert transport_request.valid?
    assert transport_request.save
    assert_equal 1, transport_request.package_items.count
  end

  test "can destroy package_items through nested attributes" do
    transport_request = transport_requests(:packages_mode)
    package_item = transport_request.package_items.first

    transport_request.update(
      package_items_attributes: [
        {
          id: package_item.id,
          _destroy: "1"
        }
      ]
    )

    assert_not transport_request.package_items.include?(package_item)
  end

  test "rejects blank package_items in nested attributes" do
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      shipping_mode: "packages",
      package_items_attributes: [
        {
          package_type: "",
          quantity: nil,
          weight_kg: nil
        }
      ]
    )

    assert transport_request.valid?
    assert_equal 0, transport_request.package_items.size
  end

  # ========== DATABASE CONSTRAINTS ==========

  test "foreign key constraint enforced for user" do
    transport_request = TransportRequest.new(
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      transport_request.save!
    end
  end

  test "references user correctly" do
    transport_request = transport_requests(:packages_mode)
    assert_equal users(:customer_one), transport_request.user
  end

  # ========== FIXTURE DATA VALIDATION ==========

  test "fixture data is valid" do
    assert transport_requests(:packages_mode).valid?
    assert transport_requests(:loading_meters_mode).valid?
    assert transport_requests(:vehicle_booking_mode).valid?
    assert transport_requests(:completed_request).valid?
  end
end
