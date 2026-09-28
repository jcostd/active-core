require "test_helper"

class MemberTest < ActiveSupport::TestCase
  def setup
    @member = Member.new(
      first_name: "  mario  ",
      last_name: "ROSSI",
      fiscal_code: "rssmra80a01h501u",
      birth_date: "1980-01-01",
      email_address: "  MARIO@test.com "
    )
  end

  test "normalization cleans data automatically" do
    @member.save!

    assert_equal "Mario", @member.first_name
    assert_equal "Rossi", @member.last_name
    assert_equal "mario@test.com", @member.email_address
    assert_equal "RSSMRA80A01H501U", @member.fiscal_code # Upcase fondamentale
  end

  test "virtual column full_name works" do
    @member.save!
    # Rileggiamo dal DB per attivare la colonna virtuale
    reloaded = Member.find(@member.id)
    assert_equal "Mario Rossi", reloaded.full_name
  end

  test "enforces fiscal_code uniqueness only for kept records" do
    @member.save!

    # 1. Prova a creare un duplicato (deve fallire)
    duplicate = @member.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:fiscal_code], "è già presente"

    # 2. Cestina il primo socio
    @member.discard!

    # 3. Ora il duplicato deve essere valido (perché il primo è 'morto')
    assert duplicate.valid?
  end

  test "a member with payments cannot be hard deleted" do
    member = members(:alice)
    grant_membership_to(member)

    assert_not member.destroy
    assert Member.exists?(member.id)
    assert member.errors[:base].any?
  end

  # --- RINNOVI E VALIDITÀ ---

  test "next period continues after the last subscription within the grace period" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31))

    assert_equal Date.new(2026, 9, 1), alice.next_period_for(quota, from: Date.new(2026, 9, 20)).start_date
    assert_equal Date.new(2026, 9, 1), alice.next_period_for(quota, from: Date.new(2026, 8, 10)).start_date, "rinnovo anticipato"
  end

  test "next period restarts from the given day after the grace period" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2024, 9, 1), end_date: Date.new(2025, 8, 31))

    from = Date.new(2025, 8, 31) + Member::RENEWAL_GRACE_PERIOD + 2
    assert_equal from, alice.next_period_for(quota, from:).start_date
  end

  test "next period ignores discarded subscriptions" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31)).discard!

    assert_equal Date.new(2026, 9, 20), alice.next_period_for(quota, from: Date.new(2026, 9, 20)).start_date
  end

  test "next period continues within the same discipline, even changing product" do
    alice = members(:alice)
    monthly   = link!(products(:yoga_monthly), disciplines(:yoga))
    quarterly = link!(Product.create!(name: "Yoga Trimestrale", price_cents: 12000, duration_days: 90), disciplines(:yoga))
    Subscription.create!(member: alice, product: monthly, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30))

    period = alice.next_period_for(quarterly, from: Date.new(2026, 10, 15))
    assert_equal [ Date.new(2026, 10, 1), Date.new(2026, 12, 31) ], [ period.start_date, period.end_date ]
  end

  test "next period does not continue across disciplines" do
    alice = members(:alice)
    boxe = link!(Product.create!(name: "Boxe Annuale", price_cents: 30000, duration_days: 365),
                 Discipline.create!(name: "Boxe"))
    yoga = link!(Product.create!(name: "Yoga Annuale", price_cents: 30000, duration_days: 365), disciplines(:yoga))
    Subscription.create!(member: alice, product: boxe, start_date: Date.new(2025, 9, 10), end_date: Date.new(2026, 9, 9))

    assert_equal Date.new(2026, 9, 20), alice.next_period_for(yoga, from: Date.new(2026, 9, 20)).start_date
    assert_equal Date.new(2026, 9, 10), alice.next_period_for(boxe, from: Date.new(2026, 9, 20)).start_date
  end

  test "a course does not continue a membership and vice versa" do
    alice = members(:alice)
    Subscription.create!(member: alice, product: products(:annual_membership), start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31))

    assert_equal Date.new(2026, 9, 1), alice.next_period_for(products(:yoga_monthly), from: Date.new(2026, 9, 20)).start_date,
                 "il mensile si allinea al mese, non alla quota"
    assert_equal Date.new(2026, 9, 20), alice.next_period_for(link!(Product.create!(name: "Yoga Annuale", price_cents: 1, duration_days: 365), disciplines(:yoga)),
                                                              from: Date.new(2026, 9, 20)).start_date
  end

  test "any membership product continues any other membership" do
    alice = members(:alice)
    Subscription.create!(member: alice, product: products(:annual_membership), start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31))
    reduced = Product.create!(name: "Quota Ridotta", price_cents: 1000, duration_days: 365, accounting_category: :associative)

    assert_equal Date.new(2026, 9, 1), alice.next_period_for(reduced, from: Date.new(2026, 9, 10)).start_date
  end

  test "next period queues after an already bought future subscription" do
    alice = members(:alice)
    course = products(:yoga_monthly)
    Subscription.create!(member: alice, product: course, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30))
    Subscription.create!(member: alice, product: course, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 31))

    assert_equal Date.new(2026, 11, 1), alice.next_period_for(course, from: Date.new(2026, 9, 15)).start_date
  end

  test "august membership lasts until the end of the next sport year" do
    period = members(:bob).next_period_for(products(:annual_membership), from: Date.new(2026, 8, 20))
    assert_equal [ Date.new(2026, 8, 20), Date.new(2027, 8, 31) ], [ period.start_date, period.end_date ]
  end

  test "membership_valid? agrees whether subscriptions are loaded or not" do
    alice = members(:alice)
    grant_membership_to(alice)

    [ Date.current, 10.years.from_now.to_date ].each do |date|
      fresh  = Member.find(alice.id).membership_valid?(date)
      loaded = Member.includes(subscriptions: :product).find(alice.id).membership_valid?(date)
      assert_equal fresh, loaded, date
    end
  end

  test "membership_valid? ignores discarded memberships" do
    alice = members(:alice)
    sub = Subscription.create!(member: alice, product: products(:annual_membership), start_date: Date.current, end_date: Date.current + 30)
    assert alice.membership_valid?

    sub.discard!
    assert_not alice.reload.membership_valid?
  end

  test "medical certificate validity is inclusive of the expiry day" do
    member = Member.new(medical_certificate_expiry: Date.current)
    assert member.medical_certificate_valid?
    assert_not member.medical_certificate_valid?(Date.current + 1)
    assert_not Member.new.medical_certificate_valid?
  end

  test "relevant subscriptions keep the latest per product within 30 days" do
    alice = members(:alice)
    quota = products(:annual_membership)
    old   = Subscription.create!(member: alice, product: quota, start_date: Date.current - 400, end_date: Date.current - 35)
    last  = Subscription.create!(member: alice, product: quota, start_date: Date.current - 30, end_date: Date.current + 300)

    assert_equal [ last ], alice.relevant_subscriptions
    assert_not_includes alice.relevant_subscriptions, old
  end

  test "full address skips the missing parts" do
    member = Member.new(address: "via roma 1", city: "roma", zip_code: "00100")
    assert_equal "Via Roma 1, Roma (00100)", member.full_address

    member.zip_code = nil
    assert_equal "Via Roma 1, Roma", member.full_address
    assert_equal "Roma", Member.new(city: "Roma").full_address
    assert_nil Member.new.full_address
  end

  test "fiscal code must be 16 alphanumeric chars" do
    member = members(:alice)
    member.fiscal_code = "abc"
    assert_not member.valid?
    assert member.errors[:fiscal_code].any?
  end

  test "phone must be a plausible number" do
    member = members(:alice)
    member.phone = "12"
    assert_not member.valid?

    member.phone = ""
    member.validate
    assert_empty member.errors[:phone]
  end

  test "fiscal code must pass the check character" do
    member = members(:alice)
    member.fiscal_code = "RSSMRA80A01H501Z"
    assert_not member.valid?
    assert_includes member.errors[:fiscal_code], "non è valido: controlla lettere, cifre e carattere finale"

    member.fiscal_code = "rssmra80a01h501u"
    assert member.valid?
  end

  test "blank fiscal code asks to fill it or mark it pending" do
    member = members(:alice)
    member.fiscal_code = " "
    assert_not member.valid?
    assert_equal [ "non può essere lasciato in bianco: inseriscilo o spunta \"CF da completare\"" ], member.errors[:fiscal_code]
  end

  test "touching a member with an old invalid code does not fail" do
    member = members(:alice)
    member.update_column(:fiscal_code, "VECCHIOCODICE000")
    assert_nothing_raised { member.touch }
  end

  # --- CF DA COMPLETARE ---

  test "new member without fiscal code when marked pending" do
    member = Member.create!(first_name: "Ana", last_name: "Silva", birth_date: "1990-05-05", fiscal_code: "", fiscal_code_pending: true)
    assert_nil member.fiscal_code
    assert_includes Member.missing_fiscal_code, member
  end

  test "several pending members do not collide" do
    2.times { |i| Member.create!(first_name: "Ospite#{i}", last_name: "Estero", birth_date: "1990-05-05", fiscal_code_pending: true) }
    assert_equal 2, Member.missing_fiscal_code.count
  end

  test "pending members stay editable without ticking the box again" do
    member = Member.create!(first_name: "Ana", last_name: "Silva", birth_date: "1990-05-05", fiscal_code_pending: true)
    reloaded = Member.find(member.id)

    assert reloaded.fiscal_code_pending?
    assert reloaded.update(phone: "3331234567")
  end

  test "an existing fiscal code cannot be wiped by mistake" do
    member = members(:alice)
    assert_not member.update(fiscal_code: "")
  end

  test "completing a pending fiscal code validates it" do
    member = Member.create!(first_name: "Ana", last_name: "Silva", birth_date: "1990-05-05", fiscal_code_pending: true)
    assert_not member.update(fiscal_code: "RSSMRA80A01H501Z")
    assert member.update(fiscal_code: "RSSMRA80A01H501U")
    assert_not member.reload.fiscal_code_pending?
  end

  test "full text index is kept in sync by database triggers" do
    triggers = Member.connection.select_values("SELECT name FROM sqlite_master WHERE type = 'trigger'")
    assert_equal %w[members_ad members_ai members_au], triggers.grep(/\Amembers_/).sort

    member = Member.create!(first_name: "Zebedeo", last_name: "Nuovo", birth_date: "1990-05-05", fiscal_code_pending: true)
    assert_includes Member.search_text("zebedeo"), member
  end

  test "surnames with apostrophes are found by any part" do
    member = Member.create!(first_name: "Rosa", last_name: "d'amico", birth_date: "1990-05-05", fiscal_code_pending: true)

    assert_equal "D'Amico", member.last_name
    assert_includes Member.search_text("amico"), member
    assert_includes Member.search_text("d'amico"), member
    assert_includes Member.search_text("D'AMICO rosa"), member
  end

  test "legacy member with an invalid code can still be edited" do
    member = members(:alice)
    member.update_column(:fiscal_code, "NO11111111111111")
    assert member.reload.update(phone: "3339998877")
  end
end
