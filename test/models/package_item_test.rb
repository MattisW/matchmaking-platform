require "test_helper"

class PackageItemTest < ActiveSupport::TestCase
  # Associations
  test "should belong to transport_request" do
    package_item = package_items(:euro_pallet_one)
    assert_respond_to package_item, :transport_request
    assert_instance_of TransportRequest, package_item.transport_request
  end

  test "should have inverse_of association" do
    transport_request = transport_requests(:packages_mode)
    package_item = transport_request.package_items.build(
      package_type: "test",
      quantity: 1,
      weight_kg: 100
    )

    assert_equal transport_request, package_item.transport_request
  end

  # Validations - Required Fields
  test "should require package_type" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      quantity: 1,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:package_type], "can't be blank"
  end

  test "should require quantity" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: nil,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "can't be blank"
  end

  test "should require weight_kg" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:weight_kg], "can't be blank"
  end

  # Validations - Numericality
  test "quantity must be an integer" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1.5,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "must be an integer"
  end

  test "quantity must be greater than zero" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 0,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "must be greater than 0"
  end

  test "quantity cannot be negative" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: -1,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "must be greater than 0"
  end

  test "weight_kg must be greater than zero" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 0
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:weight_kg], "must be greater than 0"
  end

  test "weight_kg cannot be negative" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: -10
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:weight_kg], "must be greater than 0"
  end

  # Optional Dimension Validations
  test "can save with nil dimensions" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "custom_box",
      quantity: 1,
      weight_kg: 50,
      length_cm: nil,
      width_cm: nil,
      height_cm: nil
    )

    assert package_item.valid?
  end

  test "length_cm must be greater than zero if present" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100,
      length_cm: 0
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:length_cm], "must be greater than 0"
  end

  test "width_cm must be greater than zero if present" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100,
      width_cm: -5
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:width_cm], "must be greater than 0"
  end

  test "height_cm must be greater than zero if present" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100,
      height_cm: 0
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:height_cm], "must be greater than 0"
  end

  # Edge Cases
  test "can save with decimal weight" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "custom_box",
      quantity: 1,
      weight_kg: 9.99
    )

    assert package_item.valid?
    assert package_item.save
    assert_equal 9.99, package_item.weight_kg
  end

  test "can save with realistic pallet dimensions" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 2,
      length_cm: 120,
      width_cm: 80,
      height_cm: 144,
      weight_kg: 300
    )

    assert package_item.valid?
    assert package_item.save
  end

  # Database Constraints
  test "references transport_request correctly" do
    package_item = package_items(:euro_pallet_one)
    assert_equal transport_requests(:packages_mode), package_item.transport_request
  end

  test "foreign key constraint enforced" do
    package_item = PackageItem.new(
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100
    )

    # Should fail without transport_request
    assert_raises(ActiveRecord::RecordInvalid) do
      package_item.save!
    end
  end

  # Fixture Data Validation
  test "fixture data is valid" do
    assert package_items(:euro_pallet_one).valid?
    assert package_items(:industrial_pallet_one).valid?
    assert package_items(:half_pallet_one).valid?
    assert package_items(:custom_box_one).valid?
  end
end
