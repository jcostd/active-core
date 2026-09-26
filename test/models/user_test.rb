require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = users(:staff)
  end

  test "valid user setup from fixtures" do
    assert @user.valid?
    assert @user.staff?
  end

  test "normalization cleans username" do
    user = User.new(
      username: "  MarioRossi  ", # Spazi e maiuscole
      first_name: "Mario",
      last_name: "Rossi",
      email_address: "mario@test.it",
      password: "password123"
    )
    user.validate # Triggera normalizes

    assert_equal "mariorossi", user.username
  end

  test "username format validation" do
    @user.username = "bad name!" # Spazi e punti esclamativi vietati
    assert_not @user.valid?
    assert_includes @user.errors[:username], "può contenere solo lettere minuscole, numeri e underscore"
  end

  test "password length enforcement" do
    user = User.new(
      username: "newuser",
      first_name: "A", last_name: "B",
      email_address: "a@b.com",
      password: "sho" # 3 char
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "è troppo corto (il minimo è 4 caratteri)"

    user.password = "longenough"
    assert user.valid?
  end

  test "personable concern integration" do
    # Verifica che le validazioni del concern Personable (es. nome obbligatorio) siano attive
    @user.first_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:first_name], "non può essere lasciato in bianco"
  end

  test "cannot delete user with associated sales" do
    reflection = User.reflect_on_association(:sales)
    assert_equal :restrict_with_error, reflection.options[:dependent]
  end

  test "soft delete works" do
    assert_nil @user.discarded_at
    @user.discard!
    assert @user.discarded?
    assert @user.discarded_at.present?
  end

  test "the last admin cannot lose the role" do
    admin = users(:admin)
    assert_not admin.update(role: :staff)
    assert_includes admin.errors[:role], "non può essere cambiato: serve almeno un amministratore"
  end

  test "an admin can be demoted when another one exists" do
    users(:staff).update!(role: :admin)
    assert users(:admin).update(role: :staff)
  end

  test "archived admins do not count" do
    other = users(:staff)
    other.update!(role: :admin)
    other.discard!
    assert_not users(:admin).update(role: :staff)
  end
end
