require "test_helper"

class PersonableTest < ActiveSupport::TestCase
  test "normalizes names and email before validation" do
    user = User.new(
      first_name: "  luigi  ",
      last_name: "  verdi  ",
      email_address: "  LUIGI@TEST.COM  ",
      username: "luigiverdi",
      password: "password"
    )

    user.validate # Triggera normalizes

    assert_equal "Luigi", user.first_name
    assert_equal "Verdi", user.last_name
    assert_equal "luigi@test.com", user.email_address
  end

  test "validates presence of names" do
    user = User.new(email_address: "valid@test.com")
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "validates email format" do
    user = User.new(first_name: "A", last_name: "B", username: "C", password: "P")

    user.email_address = "not-an-email"
    user.validate
    assert_includes user.errors[:email_address], "is invalid"

    user.email_address = "valid@email.com"
    user.validate
    assert_not user.errors[:email_address].present?
  end
end
