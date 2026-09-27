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

  test "keeps italian surnames and intentional casing" do
    member = Member.new(first_name: "ANNA-MARIA", last_name: "d'amico")
    assert_equal [ "Anna-Maria", "D'Amico" ], [ member.first_name, member.last_name ]

    member.last_name = "McDonald"
    assert_equal "McDonald", member.last_name

    member.last_name = "DELL'ORTO"
    assert_equal "Dell'Orto", member.last_name
  end

  test "normalized names survive the round trip and full_name" do
    member = members(:bob)
    member.update!(first_name: "ștefan", last_name: "o'neill")

    assert_equal "Ștefan O'Neill", member.reload.full_name
  end

  test "users get the same name rules" do
    user = User.new(first_name: "GIAN-LUCA", last_name: "d’angelo")
    assert_equal [ "Gian-Luca", "D’Angelo" ], [ user.first_name, user.last_name ]
  end

  test "blank names become nil and fail presence" do
    user = User.new(first_name: "   ", last_name: "")
    assert_nil user.first_name
    assert_not user.valid?
    assert_includes user.errors[:first_name], "non può essere lasciato in bianco"
  end

  test "validates presence of names" do
    user = User.new(email_address: "valid@test.com")
    assert_not user.valid?
    assert_includes user.errors[:first_name], "non può essere lasciato in bianco"
    assert_includes user.errors[:last_name], "non può essere lasciato in bianco"
  end

  test "validates email format" do
    user = User.new(first_name: "A", last_name: "B", username: "C", password: "P")

    user.email_address = "not-an-email"
    user.validate
    assert_includes user.errors[:email_address], "non è valido"

    user.email_address = "valid@email.com"
    user.validate
    assert_not user.errors[:email_address].present?
  end
end
