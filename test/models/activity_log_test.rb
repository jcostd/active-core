require "test_helper"

class ActivityLogTest < ActiveSupport::TestCase
  setup do
    @staff = users(:staff)
    @member = members(:alice)

    grant_membership_to(@member)
  end


  test "requires user, subject and action" do
    log = ActivityLog.new
    assert_not log.valid?

    assert_includes log.errors[:user], "deve esistere"
    assert_includes log.errors[:subject], "deve esistere"
    assert_includes log.errors[:action], "non può essere lasciato in bianco"
  end



  test "changes_set defaults to empty hash" do
    log = ActivityLog.create!(
      user: @staff,
      subject: @member,
      action: "view"
    )

    assert_equal({}, log.changes_set)
  end
end
