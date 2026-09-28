require "test_helper"

class StandingTest < ActiveSupport::TestCase
  setup do
    @alice = members(:alice)
    @yoga = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga)
    @month = Date.current.all_month
    @alice.update!(medical_certificate_expiry: 1.year.from_now)
  end

  test "no subscription of the discipline in the month: not enrolled" do
    grant_membership_to(@alice)
    subscribe(link!(Product.create!(name: "Solo Pesi", price_cents: 100, duration_days: 30), disciplines(:sala_pesi)))

    assert_standing :not_enrolled, "Non iscritto", :error
  end

  test "not enrolled wins over a missing membership" do
    assert_standing :not_enrolled, "Non iscritto", :error
  end

  test "enrolled without a membership valid today" do
    subscribe(@course, paid: true)

    assert_standing :no_membership, "Quota mancante", :error
  end

  test "a discipline that does not require the membership ignores it" do
    open_day = disciplines(:open_day)
    subscribe(link!(Product.create!(name: "Prova", price_cents: 0, duration_days: 30), open_day), paid: true)

    assert_equal :paid, standing(discipline: open_day).key
  end

  test "enrolled with something left to pay" do
    grant_membership_to(@alice)
    subscribe(@course)

    assert_standing :due, "Da saldare", :warning
  end

  test "any unpaid subscription of the month makes it due" do
    grant_membership_to(@alice)
    subscribe(@course, paid: true)
    quarter = link!(Product.create!(name: "Yoga Trimestre", price_cents: 12000, duration_days: 90), @yoga)
    subscribe(quarter)

    assert_equal 2, standing.enrollments.size
    assert_equal :due, standing.key
  end

  test "enrolled and paid" do
    grant_membership_to(@alice)
    sell!(member: @alice, product: @course, start_date: @month.first)

    assert_standing :paid, "Saldato", :ok
  end

  test "a written off debt counts as paid" do
    grant_membership_to(@alice)
    subscription = subscribe(@course)
    subscription.update!(agreed_price_cents: 0)

    assert_equal :paid, standing.key
  end

  test "an expired certificate turns a paid member into a warning" do
    grant_membership_to(@alice)
    subscribe(@course, paid: true)
    @alice.update!(medical_certificate_expiry: Date.yesterday)

    assert standing.certificate_missing?
    assert_equal [ :paid, :warning ], [ standing.key, standing.tone ]
  end

  test "certificate is not asked where the discipline does not require it" do
    @alice.update!(medical_certificate_expiry: nil)

    assert standing.certificate_missing?
    assert_not standing(discipline: disciplines(:open_day)).certificate_missing?
  end

  test "a closed month is judged on its last day" do
    last_month = Date.current.prev_month
    Subscription.create!(member: @alice, product: products(:annual_membership),
                         start_date: last_month.beginning_of_month - 1.year, end_date: last_month.beginning_of_month + 9)
    Subscription.create!(member: @alice, product: @course, start_date: last_month.beginning_of_month, end_date: last_month.end_of_month,
                         agreed_price_cents: 0)
    @alice.update!(medical_certificate_expiry: last_month.end_of_month)

    closed = Standing.new(member: @alice, discipline: @yoga, month: last_month)
    assert_equal :no_membership, closed.key, "quota finita a metà mese"
    assert_not closed.certificate_missing?, "certificato valido fino all'ultimo giorno"
    assert_equal :not_enrolled, standing.key, "questo mese non è iscritto"
  end

  test "month is normalized to its first day" do
    assert_equal Date.current.beginning_of_month, Standing.new(member: @alice, discipline: @yoga, month: Date.current.end_of_month).month
  end

  test "every key has a label" do
    assert_equal %i[not_enrolled no_membership due paid], Standing::LABELS.keys
  end

  test "same answer with preloaded subscriptions" do
    grant_membership_to(@alice)
    subscribe(@course)

    preloaded = Member.preload(subscriptions: [ :sales, { product: :disciplines } ]).find(@alice.id)
    assert_equal standing.key, Standing.new(member: preloaded, discipline: @yoga).key
  end

  private
    def standing(discipline: @yoga) = Standing.new(member: Member.find(@alice.id), discipline:)

    def assert_standing(key, label, tone)
      assert_equal [ key, label, tone ], [ standing.key, standing.label, standing.tone ]
    end

    def subscribe(product, paid: false)
      Subscription.create!(member: @alice, product:, start_date: @month.first, end_date: @month.last,
                           agreed_price_cents: paid ? 0 : product.price_cents.nonzero? || 1000)
    end
end
