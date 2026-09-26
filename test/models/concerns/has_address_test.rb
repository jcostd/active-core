require "test_helper"

class HasAddressTest < ActiveSupport::TestCase
  test "normalizes dirty inputs on assignment" do
    bob = members(:bob)
    bob.address = "  piazza navona 1  "
    bob.city = "  roma  "
    bob.zip_code = " I-00100 ! "

    assert_equal "Piazza Navona 1", bob.address
    assert_equal "Roma", bob.city
    assert_equal "00100", bob.zip_code
  end
end
