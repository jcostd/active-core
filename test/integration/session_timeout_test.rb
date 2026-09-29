require "test_helper"

class SessionTimeoutTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:staff)
    sign_in_as(@user)
    @session = Current.session
  end

  test "active session keeps working and records activity" do
    travel Session::IDLE_TIMEOUT - 1.minute

    get root_path
    assert_response :success
    assert_in_delta Time.current, @session.reload.updated_at, 1.second
  end

  test "idle session is destroyed and redirected with a message" do
    travel Session::IDLE_TIMEOUT + 1.minute

    get members_path

    assert_redirected_to new_session_path
    assert_not Session.exists?(@session.id)
    follow_redirect!
    assert_select "div", /Sessione scaduta per inattività/
  end

  test "return_to is stored only for GET" do
    travel Session::IDLE_TIMEOUT + 1.minute
    post members_path, params: { member: { first_name: "X" } }
    assert_nil session[:return_to_after_authenticating]

    get members_path
    assert_equal members_url, session[:return_to_after_authenticating]
  end

  test "kiosk user is exempt from the idle timeout" do
    sign_in_as(users(:kiosk))

    travel Session::IDLE_TIMEOUT * 5
    get kiosk_root_path
    assert_response :success
  end

  test "staff using the kiosk keeps the idle timeout" do
    get kiosk_root_path
    assert_response :success

    travel Session::IDLE_TIMEOUT + 1.minute
    get kiosk_root_path
    assert_redirected_to new_session_path
  end

  test "idle session cannot be revived by opening the kiosk" do
    travel Session::IDLE_TIMEOUT + 1.minute

    get kiosk_root_path
    assert_redirected_to new_session_path
    assert_not Session.exists?(@session.id)

    get members_path
    assert_redirected_to new_session_path
  end

  test "client idle sign out shows a message" do
    delete session_path(reason: "idle")

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "div", /Sessione scaduta per inattività/
  end

  test "app layout carries the idle timer, kiosk layout does not" do
    get root_path
    assert_select "body[data-controller~=idle][data-idle-timeout-value='#{Session::IDLE_TIMEOUT.to_i}']"

    get kiosk_root_path
    assert_select "body[data-controller~=idle]", count: 0
  end
end
