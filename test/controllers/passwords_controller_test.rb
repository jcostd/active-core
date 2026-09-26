require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "riceverai le istruzioni"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "riceverai le istruzioni"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "non è valido o è scaduto"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "newpass", password_confirmation: "newpass" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "Password reimpostata"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "non coincidono"
  end

  test "create for a discarded user sends no mail" do
    @user.discard!

    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_emails 0
  end

  test "edit with token of a discarded user" do
    token = @user.password_reset_token
    @user.discard!

    get edit_password_path(token)
    assert_redirected_to new_password_path
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
