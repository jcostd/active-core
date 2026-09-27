require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @session = users(:staff).sessions.create!
    @kiosk = users(:kiosk).sessions.create!
  end

  test "expires after idle timeout" do
    travel Session::IDLE_TIMEOUT - 1.minute
    assert_not @session.expired?

    travel 2.minutes
    assert @session.expired?
  end

  test "admin sessions have the idle timeout too" do
    admin = users(:admin).sessions.create!
    travel Session::IDLE_TIMEOUT + 1.minute
    assert admin.expired?
  end

  test "kiosk user sessions use the kiosk timeout" do
    travel Session::IDLE_TIMEOUT + 1.minute
    assert_not @kiosk.expired?

    travel Session::KIOSK_TIMEOUT # margine per il cambio ora legale incluso nei minuti già passati
    assert @kiosk.expired?
  end

  test "timeout depends on the user" do
    assert_equal Session::IDLE_TIMEOUT, @session.timeout
    assert_equal Session::KIOSK_TIMEOUT, @kiosk.timeout
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

  test "record_activity! does not touch the user" do
    travel Session::ACTIVITY_INTERVAL + 1.second
    assert_no_changes -> { users(:staff).reload.updated_at } do
      @session.record_activity!
    end
  end

  test "sweep removes idle sessions and keeps the kiosk ones" do
    travel Session::IDLE_TIMEOUT + 1.minute
    fresh = users(:admin).sessions.create!

    Session.sweep

    assert_not Session.exists?(@session.id)
    assert Session.exists?(@kiosk.id)
    assert Session.exists?(fresh.id)
  end

  test "sweep removes kiosk sessions unused for the kiosk timeout" do
    travel Session::KIOSK_TIMEOUT + 1.day # margine per il cambio ora legale

    Session.sweep

    assert_not Session.exists?(@kiosk.id)
  end

  test "sweep and expired? agree" do
    travel Session::IDLE_TIMEOUT + 1.minute
    assert_equal Session.all.select(&:expired?).map(&:id).sort, Session.expired.pluck(:id).sort
  end

  test "find_resumable ignores discarded users" do
    users(:staff).update_column(:discarded_at, Time.current)
    assert_nil Session.find_resumable(@session.id)
  end
end
