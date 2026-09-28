require "test_helper"

class AccessLogTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    @staff = users(:staff)
    @product = products(:yoga_monthly)
    @product.update!(duration_days: 30)

    grant_membership_to(@member)

    @subscription = sell!(member: @member, product: @product, user: @staff).subscription
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

  test "registers access with expired subscription (non-blocking)" do
    # Mandiamo l'abbonamento nel passato
    # Start: 60 giorni fa, End: 30 giorni fa
    @subscription.update_columns(start_date: 60.days.ago, end_date: 30.days.ago)

    log = AccessLog.new(
      member: @member,
      subscription: @subscription,
      checkin_by_user: @staff
    )

    # L'ingresso NON deve essere bloccato a livello di database.
    # Il sistema lo salva, poi sarà la AccessPolicy a gestirne lo 'status' (ok, warning, error)
    assert log.valid?, "AccessLog dovrebbe essere valido e salvabile anche con abbonamento scaduto"
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

  # --- CARNET E DOPPIO TOCCO ---

  test "valid entry links the active subscription" do
    link!(@product, disciplines(:yoga))
    log = AccessLog.create!(member: @member, discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    assert_equal @subscription, log.subscription
    assert_not log.error?
  end

  test "error entries have no subscription" do
    log = AccessLog.create!(member: members(:bob), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    assert log.error?
    assert_nil log.subscription
  end


  test "outcome notes explain the evaluated check-in" do
    log = AccessLog.create!(member: members(:bob), discipline: disciplines(:yoga), checkin_by_user: @staff)

    assert log.error?
    assert_includes log.outcome_notes, "Quota Associativa scaduta o mancante."
    assert_empty AccessLog.find(log.id).outcome_notes
  end

  test "outcome notes are empty for a clean check-in" do
    link!(@product, disciplines(:yoga))
    @subscription.update!(start_date: Date.current - 1, end_date: Date.current + 30) # lontano dalla scadenza, qualunque sia oggi
    log = AccessLog.create!(member: @member, discipline: disciplines(:yoga), checkin_by_user: @staff)

    assert log.ok?
    assert_empty log.outcome_notes
  end

  test "double tap within the timeout is rejected" do
    first = AccessLog.create!(member: members(:alice), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    again = AccessLog.new(member: members(:alice), discipline: disciplines(:yoga), checkin_by_user: users(:staff))

    assert_not again.valid?
    assert_match "10 minuti", again.errors.full_messages.to_sentence

    travel AccessLog::DOUBLE_TAP_TIMEOUT + 1.second
    assert again.valid?
    assert first.persisted?
  end

  test "double tap is per discipline" do
    AccessLog.create!(member: members(:alice), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    assert AccessLog.new(member: members(:alice), discipline: disciplines(:sala_pesi), checkin_by_user: users(:staff)).valid?
  end
end
