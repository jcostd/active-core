require "test_helper"

class ActivityLogTest < ActiveSupport::TestCase
  setup do
    @staff = users(:staff)
    @member = members(:alice)

    grant_membership_to(@member)
  end

  test "valid activity log creation" do
    log = ActivityLog.new(
      user: @staff,
      subject: @member,
      action: "create",
      changes_set: { name: [ "Old", "New" ] }
    )

    assert log.valid?
    assert log.save
  end

  test "requires user, subject and action" do
    log = ActivityLog.new
    assert_not log.valid?

    assert_includes log.errors[:user], "deve esistere"
    assert_includes log.errors[:subject], "deve esistere"
    assert_includes log.errors[:action], "non può essere lasciato in bianco"
  end

  test "polymorphism works with different models" do
    log_member = ActivityLog.create!(
      user: @staff,
      subject: @member,
      action: "update"
    )
    assert_equal "Member", log_member.subject_type
    assert_equal @member.id, log_member.subject_id

    product = products(:yoga_monthly)
    product.update_columns(price_cents: 5000)

    sale = Sale.create!(
      member: @member,
      product: product,
      user: @staff,
      sold_on: Date.today,
      payment_method: :cash
    )

    log_sale = ActivityLog.create!(
      user: @staff,
      subject: sale,
      action: "destroy"
    )
    assert_equal "Sale", log_sale.subject_type
    assert_equal sale.id, log_sale.subject_id
  end

  test "handles json changes_set correctly" do
    changes = {
      "status" => [ "active", "suspended" ],
      "notes" => [ nil, "Late payment" ]
    }

    log = ActivityLog.create!(
      user: @staff,
      subject: @member,
      action: "update",
      changes_set: changes
    )

    log.reload

    assert_equal "active", log.changes_set["status"][0]
    assert_equal "suspended", log.changes_set["status"][1]
    assert_nil log.changes_set["notes"][0]
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
