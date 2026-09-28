require "test_helper"

class AttendanceTest < ActiveSupport::TestCase
  setup do
    @alice, @bob = members(:alice), members(:bob)
    @yoga, @pesi = disciplines(:yoga), disciplines(:sala_pesi)
    @course = link!(products(:yoga_monthly), @yoga)
    @month = Date.current.beginning_of_month
  end

  test "defaults to the current month and stores its first day" do
    assert_equal @month, mark(@alice).month
    assert_equal Date.current.prev_month.beginning_of_month, mark(@bob, month: Date.current.prev_month.end_of_month, by: users(:admin)).month
  end

  test "one row per member, discipline and month" do
    mark(@alice)

    duplicate = build(@alice)
    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages, "Socio è già nel registro di questo mese"

    assert build(@alice, discipline: @pesi).valid?, "un'altra disciplina"
    assert build(@alice, month: Date.current.prev_month, by: users(:admin)).valid?, "un altro mese"
    assert build(@bob).valid?, "un altro socio"
  end

  test "the database refuses a duplicate that skips validations" do
    mark(@alice)
    assert_raises(ActiveRecord::RecordNotUnique) { build(@alice, month: Date.current.end_of_month).save(validate: false) }
  end

  test "a month that has not started cannot be marked, not even by the admin" do
    attendance = build(@alice, month: Date.current.next_month, by: users(:admin))

    assert_not attendance.valid?
    assert_includes attendance.errors.full_messages, "Mese non è ancora iniziato"
  end

  test "closed months are corrected by the admin only" do
    last_month = Date.current.prev_month

    users(:kiosk, :staff).each do |user|
      attendance = build(@alice, month: last_month, by: user)
      assert_not attendance.valid?, user.username
      assert_includes attendance.errors.full_messages, "Mese è chiuso: solo un amministratore può correggerlo"
    end
    assert build(@alice, month: last_month, by: users(:admin)).valid?
  end

  test "editable_by? follows the same rule" do
    current = mark(@alice)
    closed  = mark(@bob, month: Date.current.prev_month, by: users(:admin))

    assert users(:kiosk, :staff, :admin).all? { current.editable_by?(it) }
    assert_equal [ false, false, true ], users(:kiosk, :staff, :admin).map { closed.editable_by?(it) }
    assert Attendance.editable_by?(users(:staff), Date.current.end_of_month)
    assert_not Attendance.editable_by?(users(:staff), Date.current.prev_month)
    assert_not Attendance.editable_by?(users(:admin), Date.current.next_month), "un mese futuro non si corregge"
  end

  test "archived members and disciplines cannot be marked" do
    @alice.discard!
    assert_includes build(@alice).tap(&:validate).errors.full_messages, "Socio è archiviato"

    @yoga.discard!
    assert_includes build(@bob).tap(&:validate).errors.full_messages, "Disciplina è archiviata"
  end

  test "a closed month keeps its rows when the member is archived later" do
    attendance = mark(@alice)
    @alice.discard!

    assert attendance.reload.valid?, "le regole di creazione non tornano sulle presenze esistenti"
  end

  test "in_month and attended find the register of a month" do
    this_month = mark(@alice)
    mark(@bob, month: Date.current.prev_month, by: users(:admin))
    mark(@bob, discipline: @pesi)

    assert_equal [ this_month ], @yoga.attendances.in_month(Date.current.end_of_month).to_a
    assert_equal [ @alice ], Member.attended(@yoga, Date.current).to_a
    assert_equal [ @bob ], Member.attended(@yoga, Date.current.prev_month).to_a
  end

  test "unenrolled lists who attends without a subscription of the discipline touching the month" do
    grant_membership_to(@alice)
    grant_membership_to(@bob)
    carla = person("Carla")
    dario = person("Dario")

    subscribe(@alice, @course, @month.beginning_of_month, @month.end_of_month)
    subscribe(@bob, link!(Product.create!(name: "Solo Pesi", price_cents: 100, duration_days: 30), @pesi), @month, @month.end_of_month)
    subscribe(carla, @course, @month, @month.end_of_month).discard!
    subscribe(dario, @course, @month.prev_month.beginning_of_month, @month) # finisce il primo del mese: conta

    [ @alice, @bob, carla, dario ].each { mark(it) }

    assert_equal [ @bob, carla ].map(&:id).sort, Attendance.unenrolled.pluck(:member_id).sort
  end

  test "unenrolled uses the real length of every month" do
    grant_membership_to(@alice)
    [ Date.new(2027, 2, 1), Date.new(2028, 2, 1), Date.new(2026, 12, 1), Date.new(2026, 4, 1) ].each do |month|
      travel_to month.end_of_month.noon do
        on_last_day = person("Ultimo #{month}")
        subscribe(on_last_day, @course, month.end_of_month, month.end_of_month)
        after_month = person("Dopo #{month}")
        subscribe(after_month, @course, month.next_month, month.next_month.end_of_month)

        attendances = [ mark(on_last_day, by: users(:admin)), mark(after_month, by: users(:admin)) ]
        assert_equal [ attendances.last ], Attendance.where(id: attendances).unenrolled.to_a, month.to_s
      end
    end
  end

  test "a user who marked attendances is kept" do
    user = User.create!(username: "istruttore", first_name: "Ivo", last_name: "Istruttore", email_address: "ivo@example.com", password: "segreta")
    mark(@alice, by: user)

    assert_not user.destroy
    assert User.exists?(user.id)
  end

  private
    def build(member, discipline: @yoga, month: nil, by: users(:kiosk))
      Attendance.new(member:, discipline:, month:, marked_by: by)
    end

    def mark(member, **) = build(member, **).tap(&:save!)

    def person(name) = Member.create!(first_name: name, last_name: "Prova", birth_date: 30.years.ago, fiscal_code_pending: true)

    def subscribe(member, product, start_date, end_date)
      Subscription.create!(member:, product:, start_date:, end_date:)
    end
end
