require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup { @session = users(:staff).sessions.create! }

  test "connects with an active session" do
    cookies.signed[:session_id] = @session.id
    connect
    assert_equal users(:staff), connection.current_user
  end

  test "rejects without cookie" do
    assert_reject_connection { connect }
  end

  test "rejects an idle session" do
    cookies.signed[:session_id] = @session.id
    travel Session::IDLE_TIMEOUT + 1.minute
    assert_reject_connection { connect }
  end

  test "accepts an idle kiosk session" do
    kiosk = users(:kiosk).sessions.create!
    cookies.signed[:session_id] = kiosk.id
    travel Session::IDLE_TIMEOUT + 1.minute

    connect
    assert_equal users(:kiosk), connection.current_user
  end

  test "rejects a kiosk session unused for the kiosk timeout" do
    kiosk = users(:kiosk).sessions.create!
    cookies.signed[:session_id] = kiosk.id
    travel Session::KIOSK_TIMEOUT + 1.day
    assert_reject_connection { connect }
  end

  test "rejects a discarded user" do
    users(:staff).update_column(:discarded_at, Time.current)
    cookies.signed[:session_id] = @session.id
    assert_reject_connection { connect }
  end
end
