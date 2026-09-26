require "test_helper"

class TrackableTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @staff = users(:staff)
    Current.session = @staff.sessions.create!
  end

  teardown { Current.reset }

  test "logs create with sanitized attributes" do
    sale = sell

    log = sale.activity_logs.find_by!(action: "created")
    assert_equal @staff, log.user
    assert_not log.changes_set.key?("created_at")
  end

  test "logs discard and undiscard" do
    sale = sell

    sale.discard!
    assert sale.activity_logs.exists?(action: "discarded")

    sale.undiscard!
    assert sale.activity_logs.exists?(action: "restored")
  end

  test "logs nothing without a current user" do
    Current.reset

    assert_no_difference -> { ActivityLog.count } do
      sell
    end
  end

  private
    def sell
      Sale.create!(member: @member, product: products(:yoga_monthly), user: @staff, sold_on: Date.current,
                   amount: 10, subscription_attributes: { member: @member, product: products(:yoga_monthly) })
    end
end
