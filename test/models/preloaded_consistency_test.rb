require "test_helper"

# kiosk e liste leggono gli abbonamenti precaricati, le pagine singole li interrogano:
# le due strade devono dare sempre la stessa risposta
class PreloadedConsistencyTest < ActiveSupport::TestCase
  setup do
    @today = Date.current
    @yoga, @pesi = disciplines(:yoga), disciplines(:sala_pesi)
    membership = products(:annual_membership)
    yoga_monthly = link!(products(:yoga_monthly), @yoga)
    yoga_quarter = link!(product("Yoga Trimestrale", 90), @yoga)
    mixed        = link!(product("Open Pesi Yoga", 30), @pesi, @yoga)
    no_discipline = product("Tessera Ospite", 30)

    @alice, @bob = members(:alice), members(:bob)
    subscribe @alice, membership,    -400, -40
    subscribe @alice, membership,    -39,  20
    subscribe @alice, membership,    21,   100, discarded: true
    subscribe @alice, yoga_monthly,  -60,  -31
    subscribe @alice, yoga_quarter,  -10,  5
    subscribe @alice, yoga_monthly,  6,    35   # rinnova il trimestrale: stessa disciplina
    subscribe @alice, mixed,         10,   40
    subscribe @alice, mixed,         -5,   3,   discarded: true
    subscribe @alice, no_discipline, -3,   26
    subscribe @bob,   membership,    -100, 30
    subscribe @bob,   yoga_quarter,  -80,  3    # in scadenza, non rinnovato
  end

  test "membership, valid subscription and enrollment agree with and without preload" do
    [ @alice, @bob ].each do |member|
      queried   = Member.find(member.id)
      preloaded = Member.preload(subscriptions: { product: :disciplines }).find(member.id)

      (-70..110).step(3).map { @today + it }.each do |date|
        assert_equal queried.membership_valid?(date), preloaded.membership_valid?(date), "quota di #{member.first_name} il #{date}"

        [ @yoga, @pesi ].each do |discipline|
          assert_same_answer queried.valid_subscription_for(discipline, date)&.id, preloaded.valid_subscription_for(discipline, date)&.id,
                             "abbonamento #{discipline.name} di #{member.first_name} il #{date}"
          assert_equal Member.enrolled_in(discipline, during: date.all_month).include?(member),
                       preloaded.enrollments_in(discipline, during: date.all_month).any?,
                       "iscrizione #{discipline.name} di #{member.first_name} a #{date.strftime("%m/%Y")}"
        end
      end
    end
  end

  test "active membership filter agrees with membership_valid?" do
    [ @alice, @bob, members(:deleted) ].each do |member|
      assert_equal member.membership_valid?, Member.with_active_membership.include?(member), member.first_name
    end
  end

  test "renewals preloaded for a list match the single answer" do
    listed = Subscription.preload_renewed(Subscription.all.to_a).to_h { [ it.id, it.renewed? ] }

    assert_equal Subscription.all.to_h { [ it.id, Subscription.find(it.id).renewed? ] }, listed
    assert listed.values.any? && !listed.values.all?, "lo scenario deve avere rinnovati e no"
  end

  test "dashboard expiring list, status badge and kiosk warning name the same subscriptions" do
    expiring = Subscription.expiring.to_a
    assert_not_empty expiring

    Subscription.kept.where(start_date: ..@today).find_each do |subscription|
      assert_equal expiring.include?(subscription), subscription.status.key == :expiring_soon, subscription.product.name
    end

    [ @alice, @bob ].product([ @yoga, @pesi ]).each do |member, discipline|
      policy = AccessPolicy.new(member:, discipline:).evaluate!
      next unless policy.subscription

      assert_equal policy.subscription.status.key == :expiring_soon, policy.warnings.any? { it.start_with?("Abbonamento in scadenza") },
                   "#{member.first_name} a #{discipline.name}"
    end
  end

  test "registro: who attends unenrolled in SQL is who the kiosk shows as not enrolled" do
    carla = Member.create!(first_name: "Carla", last_name: "Prova", birth_date: 30.years.ago, fiscal_code_pending: true)
    [ @alice, @bob, carla ].product([ @yoga, @pesi ]).each do |member, discipline|
      Attendance.create!(member:, discipline:, marked_by: users(:kiosk))
    end
    unenrolled = Attendance.unenrolled.pluck(:member_id, :discipline_id)

    Attendance.includes(:discipline, member: { subscriptions: [ :sales, { product: :disciplines } ] }).find_each do |attendance|
      standing = Standing.new(member: attendance.member, discipline: attendance.discipline, month: attendance.month)
      assert_equal unenrolled.include?([ attendance.member_id, attendance.discipline_id ]), standing.key == :not_enrolled,
                   "#{attendance.member.first_name} a #{attendance.discipline.name}"
    end
    assert unenrolled.any? && unenrolled.size < 6, "lo scenario deve avere iscritti e no"
  end

  test "amount paid and undo rights agree with and without preloaded payments" do
    subscription = sell!(member: @bob, product: products(:yoga_monthly), user: users(:admin), amount: 10, start_date: @today + 10).subscription
    Sale.create!(member: @bob, product: products(:yoga_monthly), user: users(:staff), amount: 15, payment_method: :cash, subscription:)
    Sale.create!(member: @bob, product: products(:yoga_monthly), user: users(:staff_two), amount: 5, payment_method: :cash, subscription:).discard!

    queried   = Subscription.find(subscription.id)
    preloaded = Subscription.includes(:sales).find(subscription.id)

    assert_equal 2500, queried.amount_paid
    assert_equal queried.amount_paid, preloaded.amount_paid
    assert_equal queried.amount_due, preloaded.amount_due
    users(:staff, :staff_two, :admin).each do |user|
      assert_equal queried.discardable_by?(user), preloaded.discardable_by?(user), user.username
    end
  end

  private
    def assert_same_answer(queried, preloaded, message)
      assert queried == preloaded, "#{message}: #{queried.inspect} con la query, #{preloaded.inspect} precaricato"
    end

    def product(name, duration_days) = Product.create!(name:, duration_days:, price_cents: 4000)

    def subscribe(member, product, from, to, discarded: false)
      Subscription.create!(member:, product:, start_date: @today + from, end_date: @today + to).tap { it.discard! if discarded }
    end
end
