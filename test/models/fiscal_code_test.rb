require "test_helper"

class FiscalCodeTest < ActiveSupport::TestCase
  test "accepts real-world valid codes" do
    %w[RSSMRA80A01H501U MRTMTT25D09F205Z LLVLCA80A41H501H].each do |code|
      assert FiscalCode.valid?(code), code
    end
  end

  test "normalizes case and spaces" do
    assert FiscalCode.valid?("  rssmra80a01h501u ")
  end

  test "rejects a wrong check character" do
    assert_not FiscalCode.valid?("RSSMRA80A01H501Z")
  end

  test "rejects a single typo" do
    assert_not FiscalCode.valid?("RSSMRA80A01H510U")
  end

  test "rejects broken structure" do
    [ "", "ABC", "RSSMRA80Z01H501U", "RSSMR480A01H501U", "RSSMRA80A01H501UX" ].each do |code|
      assert_not FiscalCode.valid?(code), code
    end
  end

  test "accepts omocodic codes with the right check character" do
    code = "RSSMRAUMA0MH501"
    assert FiscalCode.valid?(code + FiscalCode.new(code + "A").check_char)
  end
end
