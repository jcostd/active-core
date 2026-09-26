require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup { @session = users(:staff).sessions.create! }

  test "expires after idle timeout" do
    travel Session::IDLE_TIMEOUT - 1.minute
    assert_not @session.expired?

    travel 2.minutes
    assert @session.expired?
  end

  test "kiosk requests use the kiosk timeout" do
    travel Session::IDLE_TIMEOUT + 1.minute
    assert_not @session.expired?(kiosk_request: true)

    travel Session::KIOSK_TIMEOUT
    assert @session.expired?(kiosk_request: true)
  end

  test "record_activity! is throttled" do
    travel Session::ACTIVITY_INTERVAL - 1.second
    assert_no_changes -> { @session.reload.updated_at } do
      @session.record_activity!
    end

    travel 2.seconds
    assert_changes -> { @session.reload.updated_at } do
      @session.record_activity!
    end
  end

  test "record_activity! flags kiosk sessions immediately" do
    @session.record_activity!(kiosk_request: true)
    assert @session.reload.kiosk?
  end

  test "record_activity! never clears the kiosk flag" do
    @session.update_columns(kiosk: true)
    travel Session::ACTIVITY_INTERVAL + 1.second

    @session.record_activity!
    assert @session.reload.kiosk?
  end

  test "record_activity! does not touch the user" do
    travel Session::ACTIVITY_INTERVAL + 1.second
    assert_no_changes -> { users(:staff).reload.updated_at } do
      @session.record_activity!
    end
  end

  test "sweep removes idle sessions and keeps kiosk ones" do
    kiosk = users(:admin).sessions.create!(kiosk: true)
    travel Session::IDLE_TIMEOUT + 1.minute
    fresh = users(:admin).sessions.create!

    Session.sweep

    assert_not Session.exists?(@session.id)
    assert Session.exists?(kiosk.id)
    assert Session.exists?(fresh.id)
  end

  test "sweep removes kiosk sessions unused for the kiosk timeout" do
    kiosk = users(:admin).sessions.create!(kiosk: true)
    travel Session::KIOSK_TIMEOUT + 1.minute

    Session.sweep

    assert_not Session.exists?(kiosk.id)
  end

  test "find_resumable ignores discarded users" do
    users(:staff).update_column(:discarded_at, Time.current)
    assert_nil Session.find_resumable(@session.id)
  end
end
