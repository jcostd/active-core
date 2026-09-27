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

  test "normalizes codes, contacts and places" do
    profile = GymProfile.new(name: "  A.S.D.   Querini  ", vat_number: " 941 036 20277 ", bank_iban: "it11 a050 3402 0700 0000 0010 114",
                             email: " ASD@Esempio.IT ", city: "venezia", address_line_1: "calle cappuccina 6576/b", zip_code: "30 122")

    assert_equal "A.S.D. Querini", profile.name
    assert_equal "94103620277", profile.vat_number
    assert_equal "IT11A0503402070000000010114", profile.bank_iban
    assert_equal "asd@esempio.it", profile.email
    assert_equal [ "Venezia", "Calle Cappuccina 6576/B", "30122" ], [ profile.city, profile.address_line_1, profile.zip_code ]
    assert profile.valid?, profile.errors.full_messages.to_sentence
  end

  test "fiscal code of the association has 11 digits or 16 characters" do
    assert GymProfile.new(name: "ASD", vat_number: "94103620277").valid?
    assert GymProfile.new(name: "ASD", vat_number: "RSSMRA80A01H501U").valid?

    profile = GymProfile.new(name: "ASD", vat_number: "IT941036")
    assert_not profile.valid?
    assert_includes profile.errors.full_messages, "Codice fiscale / P.IVA deve avere 11 cifre o 16 caratteri"
  end

  test "iban and email are checked, blanks become nil" do
    assert_not GymProfile.new(name: "ASD", bank_iban: "12345").valid?
    assert_not GymProfile.new(name: "ASD", email: "non-una-mail").valid?

    profile = GymProfile.new(name: "ASD", bank_iban: " ", email: "", vat_number: "", phone: " ", zip_code: "")
    assert profile.valid?
    assert_nil profile.bank_iban
    assert_nil profile.vat_number
  end

  test "full_address skips blank parts" do
    profile = GymProfile.new(address_line_1: "Via Roma 1", zip_code: "00100", city: "Roma")
    assert_equal "Via Roma 1 - 00100 Roma", profile.full_address

    assert_equal "", GymProfile.new.full_address
  end
end
