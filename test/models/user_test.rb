require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = users(:staff)
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

  test "email is required" do
    @user.email_address = "  "
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "non può essere lasciato in bianco"
  end

  test "email must be unique among active users, ignoring case" do
    user = User.new(username: "nuovo", first_name: "A", last_name: "B", password: "password",
                    email_address: " STAFF@asd.it ")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "è già presente"
    assert_nothing_raised { assert_not user.save }
  end

  test "email of a discarded user can be reused" do
    users(:staff_two).discard!
    user = User.new(username: "nuovo", first_name: "A", last_name: "B", password: "password",
                    email_address: "staff2@asd.it")
    assert user.save
  end

  test "kiosk user cannot be archived, not even by an admin" do
    kiosk = users(:kiosk)

    assert_not kiosk.archivable_by?(users(:admin))
    assert_raises(ActiveRecord::RecordNotSaved) { kiosk.discard! }
    assert kiosk.reload.kept?
  end

  test "only an admin archives, and never themselves" do
    assert users(:staff).archivable_by?(users(:admin))
    assert_not users(:staff).archivable_by?(users(:staff_two))
    assert_not users(:admin).archivable_by?(users(:admin))
  end

  test "kiosk user keeps its role" do
    kiosk = users(:kiosk)
    kiosk.role = :admin
    assert_not kiosk.valid?
    assert_includes kiosk.errors[:role], "non può essere cambiato: l'utente kiosk è unico e fisso"
  end

  test "nobody else becomes kiosk" do
    @user.role = :kiosk
    assert_not @user.valid?
    assert_includes @user.errors[:role], "non può essere cambiato: l'utente kiosk è unico e fisso"

    second = User.new(username: "kiosk2", first_name: "A", last_name: "B", email_address: "k2@system.local",
                      password: "password", role: :kiosk)
    assert_not second.valid?
  end

  test "the kiosk user can be created when missing" do
    users(:kiosk).update_column(:discarded_at, Time.current)
    kiosk = User.new(username: "kiosk2", first_name: "Kiosk", last_name: "Accessi", email_address: "k2@system.local",
                     password: "password", role: :kiosk)
    assert kiosk.valid?
  end

  test "kiosk user can change name and password" do
    kiosk = users(:kiosk)
    assert kiosk.update(first_name: "iPad", password: "nuovapass", password_confirmation: "nuovapass")
    assert kiosk.authenticate("nuovapass")
  end

  test "an unknown role is a validation error, not an exception" do
    @user.role = "superuser"
    assert_not @user.valid?
    assert @user.errors[:role].any?
  end

  test "operators are staff and admins, not the kiosk" do
    assert_includes User.operators, users(:staff)
    assert_includes User.operators, users(:admin)
    assert_not_includes User.operators, users(:kiosk)
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

  test "a user who registered payments cannot be hard deleted" do
    member = members(:alice)
    grant_membership_to(member)
    sell!(member:, product: products(:yoga_monthly), user: @user)

    assert_not @user.destroy
    assert User.exists?(@user.id)
  end

  test "archiving a user closes every open session" do
    2.times { @user.sessions.create! }
    @user.discard!
    assert_equal 0, @user.sessions.count
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
