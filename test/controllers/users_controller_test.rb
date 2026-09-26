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
      post users_path, params: { user: { first_name: "X", last_name: "Y", username: "xy", email_address: "xy@asd.it", password: "secret" } }
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
