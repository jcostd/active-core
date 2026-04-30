require "test_helper"

class AccessLogTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    @staff = users(:staff)
    @product = products(:yoga_monthly)
    @product.update!(duration_days: 30)

    grant_membership_to(@member)

    @sale = Sale.create!(member: @member, product: @product, user: @staff, sold_on: Date.today)
    @subscription = Subscription.create!(member: @member, product: @product, sales: [ @sale ])
  end

  test "allows access with active subscription (auto-sets entered_at)" do
    log = AccessLog.new(
      member: @member,
      subscription: @subscription,
      checkin_by_user: @staff
      # entered_at non specificato -> deve essere settato dal callback
    )

    assert log.valid?
    assert log.save
    assert_not_nil log.entered_at # Verifica che il callback abbia funzionato
  end

  test "prevents access with expired subscription" do
    # Mandiamo l'abbonamento nel passato
    # Start: 60 giorni fa, End: 30 giorni fa
    @subscription.update_columns(start_date: 60.days.ago, end_date: 30.days.ago)

    log = AccessLog.new(
      member: @member,
      subscription: @subscription,
      checkin_by_user: @staff
    )

    assert_not log.valid?
  end

  test "prevents access with subscription of another member" do
    other_member = members(:bob)

    log = AccessLog.new(
      member: other_member, # Membro sbagliato
      subscription: @subscription, # Abbonamento di Alice
      checkin_by_user: @staff
    )

    assert_not log.valid?
  end

  test "correctly links staff user" do
    log = AccessLog.create!(
      member: @member,
      subscription: @subscription,
      checkin_by_user: @staff
    )

    assert_equal @staff, log.checkin_by_user
  end
end
