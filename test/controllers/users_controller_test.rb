require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = users(:staff)
    @admin = users(:admin)
  end

  test "staff cannot list, create or discard users" do
    sign_in_as(@staff)

    get users_path
    assert_redirected_to root_path

    assert_no_difference -> { User.count } do
      post users_path, params: { user: { first_name: "X", last_name: "Y", username: "xy", password: "secret" } }
    end
    assert_redirected_to root_path

    delete user_path(@admin)
    assert_redirected_to root_path
    assert @admin.reload.kept?
  end

  test "staff cannot edit another user" do
    sign_in_as(@staff)

    get edit_user_path(@admin)
    assert_redirected_to root_path

    assert_no_changes -> { @admin.reload.password_digest } do
      patch user_path(@admin), params: { user: { password: "pwned", password_confirmation: "pwned" } }
    end
    assert_redirected_to root_path
  end

  test "staff can edit self but not role" do
    sign_in_as(@staff)

    patch user_path(@staff), params: { user: { first_name: "Gino", role: "admin" } }

    assert_redirected_to user_path(@staff)
    @staff.reload
    assert_equal "Gino", @staff.first_name
    assert @staff.staff?
  end

  test "blank password keeps current password" do
    sign_in_as(@staff)

    assert_no_changes -> { @staff.reload.password_digest } do
      patch user_path(@staff), params: { user: { first_name: "Gino", password: "", password_confirmation: "" } }
    end
  end

  test "admin creating a user with a taken username gets the form back" do
    sign_in_as(@admin)

    assert_no_difference -> { User.count } do
      post users_path, params: { user: { first_name: "Nuovo", last_name: "Utente", username: "staff",
                                         password: "password", password_confirmation: "password" } }
    end
    assert_response :unprocessable_entity
    assert_match "Username è già presente", response.body
  end

  test "staff cannot take a colleague username" do
    sign_in_as(@staff)

    patch user_path(@staff), params: { user: { username: "staff2" } }

    assert_response :unprocessable_entity
    assert_equal "staff", @staff.reload.username
  end

  test "admin cannot archive the kiosk user" do
    sign_in_as(@admin)

    delete user_path(users(:kiosk))

    assert users(:kiosk).reload.kept?
    assert_equal "Impossibile archiviare utente.", flash[:alert]
  end

  test "users list offers no archive button for the kiosk user nor for oneself" do
    sign_in_as(@admin)
    get users_path

    assert_select "a[data-turbo-method=delete][href='#{user_path(users(:kiosk))}']", count: 0
    assert_select "a[data-turbo-method=delete][href='#{user_path(@admin)}']", count: 0
    assert_select "a[data-turbo-method=delete][href='#{user_path(@staff)}']"
  end

  test "kiosk user page has no archive action and shows its role" do
    sign_in_as(@admin)
    get user_path(users(:kiosk))

    assert_select "a", text: /Archivia Utente/, count: 0
    assert_select ".badge", text: "Kiosk"
  end

  test "kiosk edit form has no role select" do
    sign_in_as(@admin)
    get edit_user_path(users(:kiosk))

    assert_select "select[name='user[role]']", count: 0
    assert_match "Utente fisso dell'iPad", response.body
  end

  test "role select offers only staff and admin" do
    sign_in_as(@admin)
    get edit_user_path(@staff)

    assert_select "select[name='user[role]'] option", count: 2
    assert_select "select[name='user[role]'] option[value=kiosk]", count: 0
  end

  test "admin cannot turn a user into the kiosk" do
    sign_in_as(@admin)

    patch user_path(@staff), params: { user: { role: "kiosk" } }

    assert_response :unprocessable_entity
    assert @staff.reload.staff?
  end

  test "admin cannot change the kiosk role" do
    sign_in_as(@admin)

    patch user_path(users(:kiosk)), params: { user: { role: "admin" } }

    assert_response :unprocessable_entity
    assert users(:kiosk).reload.kiosk?
  end

  test "admin sets the kiosk password" do
    sign_in_as(@admin)

    patch user_path(users(:kiosk)), params: { user: { password: "ipadsala", password_confirmation: "ipadsala" } }

    assert users(:kiosk).reload.authenticate("ipadsala")
  end

  test "admin can edit another user role" do
    sign_in_as(@admin)

    patch user_path(@staff), params: { user: { role: "admin" } }

    assert @staff.reload.admin?
  end

  test "admin can discard another user" do
    sign_in_as(@admin)

    delete user_path(@staff)

    assert @staff.reload.discarded?
  end

  test "malformed params return bad request" do
    sign_in_as(@admin)

    patch user_path(@staff), params: { user: "nope" }

    assert_response :bad_request
  end
end
