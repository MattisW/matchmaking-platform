require "test_helper"

class PackageTypePresetTest < ActiveSupport::TestCase
  # ========== VALIDATIONS ==========

  test "should require name" do
    preset = PackageTypePreset.new(
      category: "pallet",
      default_length_cm: 120,
      default_width_cm: 80,
      default_height_cm: 144,
      default_weight_kg: 300
    )

    assert_not preset.valid?
    assert_includes preset.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    existing_preset = package_type_presets(:euro_pallet)

    duplicate_preset = PackageTypePreset.new(
      name: existing_preset.name,
      category: "pallet"
    )

    assert_not duplicate_preset.valid?
    assert_includes duplicate_preset.errors[:name], "has already been taken"
  end

  test "name uniqueness enforced at database level" do
    existing_preset = package_type_presets(:euro_pallet)

    duplicate_preset = PackageTypePreset.new(
      name: existing_preset.name,
      category: "pallet"
    )

    # Bypass validation to test database constraint
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_preset.save(validate: false)
    end
  end

  test "category must be valid if present" do
    preset = PackageTypePreset.new(
      name: "Test Package",
      category: "invalid_category"
    )

    assert_not preset.valid?
    assert_includes preset.errors[:category], "is not included in the list"
  end

  test "category can be pallet, box, or custom" do
    %w[pallet box custom].each do |category|
      preset = PackageTypePreset.new(
        name: "Test Package #{category}",
        category: category
      )

      assert preset.valid?, "#{category} should be valid"
    end
  end

  test "category is optional" do
    preset = PackageTypePreset.new(
      name: "Test Package without category"
    )

    assert preset.valid?
  end

  # ========== BUSINESS LOGIC ==========

  test "as_json_defaults returns correct hash structure" do
    preset = package_type_presets(:euro_pallet)

    result = preset.as_json_defaults

    assert_equal preset.default_length_cm, result[:length]
    assert_equal preset.default_width_cm, result[:width]
    assert_equal preset.default_height_cm, result[:height]
    assert_equal preset.default_weight_kg, result[:weight]
  end

  test "as_json_defaults works with nil values" do
    preset = package_type_presets(:custom_box)

    result = preset.as_json_defaults

    assert_nil result[:length]
    assert_nil result[:width]
    assert_nil result[:height]
    assert_nil result[:weight]
  end

  test "as_json_defaults returns hash with symbol keys" do
    preset = package_type_presets(:euro_pallet)

    result = preset.as_json_defaults

    assert result.key?(:length)
    assert result.key?(:width)
    assert result.key?(:height)
    assert result.key?(:weight)
  end

  # ========== DATABASE ==========

  test "can save with all attributes" do
    preset = PackageTypePreset.new(
      name: "New Test Pallet",
      category: "pallet",
      default_length_cm: 100,
      default_width_cm: 60,
      default_height_cm: 120,
      default_weight_kg: 250.5
    )

    assert preset.valid?
    assert preset.save
    assert_not_nil preset.id
  end

  test "can save with minimal attributes" do
    preset = PackageTypePreset.new(
      name: "Minimal Preset"
    )

    assert preset.valid?
    assert preset.save
  end

  test "can save with decimal weight" do
    preset = PackageTypePreset.new(
      name: "Decimal Weight Test",
      default_weight_kg: 123.45
    )

    assert preset.valid?
    assert preset.save
    assert_equal 123.45, preset.reload.default_weight_kg
  end

  # ========== FIXTURE DATA VALIDATION ==========

  test "fixture data is valid" do
    assert package_type_presets(:euro_pallet).valid?
    assert package_type_presets(:industrial_pallet).valid?
    assert package_type_presets(:half_pallet).valid?
    assert package_type_presets(:quarter_pallet).valid?
    assert package_type_presets(:custom_box).valid?
  end

  test "fixtures have correct categories" do
    assert_equal "pallet", package_type_presets(:euro_pallet).category
    assert_equal "pallet", package_type_presets(:industrial_pallet).category
    assert_equal "pallet", package_type_presets(:half_pallet).category
    assert_equal "pallet", package_type_presets(:quarter_pallet).category
    assert_equal "custom", package_type_presets(:custom_box).category
  end

  test "fixtures have expected default dimensions" do
    euro_pallet = package_type_presets(:euro_pallet)

    assert_equal 120, euro_pallet.default_length_cm
    assert_equal 80, euro_pallet.default_width_cm
    assert_equal 144, euro_pallet.default_height_cm
    assert_equal 300.0, euro_pallet.default_weight_kg
  end
end
