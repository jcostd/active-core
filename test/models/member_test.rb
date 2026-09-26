require "test_helper"

class MemberTest < ActiveSupport::TestCase
  def setup
    @member = Member.new(
      first_name: "  mario  ",
      last_name: "ROSSI",
      fiscal_code: "rssmra80a01h501z",
      birth_date: "1980-01-01",
      email_address: "  MARIO@test.com "
    )
  end

  test "normalization cleans data automatically" do
    @member.save!

    assert_equal "Mario", @member.first_name
    assert_equal "Rossi", @member.last_name
    assert_equal "mario@test.com", @member.email_address
    assert_equal "RSSMRA80A01H501Z", @member.fiscal_code # Upcase fondamentale
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

  test "prevents deletion if sales exist" do
    @member.save!
    assert_respond_to @member, :sales
    reflection = Member.reflect_on_association(:sales)
    assert_equal :restrict_with_error, reflection.options[:dependent]
  end

  # --- RINNOVI E VALIDITÀ ---

  test "suggested start continues after the last subscription within the grace period" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31))

    assert_equal Date.new(2026, 9, 1), alice.suggested_start_date_for(quota, Date.new(2026, 9, 20))
    assert_equal Date.new(2026, 9, 1), alice.suggested_start_date_for(quota, Date.new(2026, 8, 10)), "rinnovo anticipato"
  end

  test "suggested start resets to the reference date after the grace period" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2024, 9, 1), end_date: Date.new(2025, 8, 31))

    reference = Date.new(2025, 8, 31) + Member::RENEWAL_GRACE_PERIOD + 2
    assert_equal reference, alice.suggested_start_date_for(quota, reference)
  end

  test "suggested start ignores discarded subscriptions" do
    alice = members(:alice)
    quota = products(:annual_membership)
    Subscription.create!(member: alice, product: quota, start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31)).discard!

    assert_equal Date.new(2026, 9, 20), alice.suggested_start_date_for(quota, Date.new(2026, 9, 20))
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

  test "membership_valid? ignores exhausted and discarded memberships" do
    alice = members(:alice)
    sub = Subscription.create!(member: alice, product: products(:annual_membership), start_date: Date.current, end_date: Date.current + 30)
    assert alice.membership_valid?

    sub.update_columns(entry_limit: 1, entries_used: 1)
    assert_not alice.membership_valid?

    sub.update_columns(entry_limit: nil)
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

  test "valid_subscription_for returns the active course of the discipline" do
    alice = members(:alice)
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    sub = Subscription.create!(member: alice, product: course, start_date: Date.current - 1, end_date: Date.current + 10)

    assert_equal sub, alice.valid_subscription_for(disciplines(:yoga))
    assert_nil alice.valid_subscription_for(disciplines(:sala_pesi))
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
end
