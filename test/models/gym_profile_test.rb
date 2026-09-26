require "test_helper"

class GymProfileTest < ActiveSupport::TestCase
  test "current returns the single profile" do
    assert_equal GymProfile.first, GymProfile.current
    assert_no_difference(-> { GymProfile.count }) { GymProfile.current }
  end

  test "current creates a default profile when missing" do
    GymProfile.delete_all

    assert_difference -> { GymProfile.count }, 1 do
      assert_equal "ActiveCore Gym", GymProfile.current.name
    end
  end

  test "name is required" do
    assert_not GymProfile.new(name: "").valid?
  end

  test "full_address skips blank parts" do
    profile = GymProfile.new(address_line_1: "Via Roma 1", zip_code: "00100", city: "Roma")
    assert_equal "Via Roma 1 - 00100 Roma", profile.full_address

    assert_equal "", GymProfile.new.full_address
  end
end
