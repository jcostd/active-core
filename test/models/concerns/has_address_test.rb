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

  test "keeps roman numerals, civic letters and apostrophes" do
    bob = members(:bob)
    bob.address = "VIA XX SETTEMBRE 12/a"
    bob.city = "reggio nell'emilia"

    assert_equal "Via XX Settembre 12/A", bob.address
    assert_equal "Reggio Nell'Emilia", bob.city
  end

  test "blank address and city become nil" do
    bob = members(:bob)
    bob.address = "  "
    bob.city = ""

    assert_nil bob.address
    assert_nil bob.city
    assert bob.valid?
  end
end
