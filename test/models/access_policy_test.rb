require "test_helper"

class AccessPolicyTest < ActiveSupport::TestCase
  setup do
    @alice = members(:alice) # certificato valido
    @bob   = members(:bob)   # certificato scaduto
    @yoga_discipline = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga_discipline)
  end

  def policy(member, discipline = @yoga_discipline) = AccessPolicy.new(member:, discipline:).evaluate!

  test "no membership and no subscription is an error" do
    p = policy(@alice)
    assert_equal :error, p.status
    assert_includes p.errors.full_messages, "Quota Associativa scaduta o mancante."
    assert_includes p.errors.full_messages, "Nessun abbonamento attivo per 'Yoga'."
  end

  test "membership not required skips the membership check" do
    link!(@course, disciplines(:open_day))
    sell_course_to(@alice)
    @alice.subscriptions.joins(:product).merge(Product.associative).each(&:discard!)

    assert_equal :ok, policy(@alice.reload, disciplines(:open_day)).status
  end

  test "valid membership and course is ok" do
    sell_course_to(@alice, end_date: Date.current + 30)
    p = policy(@alice)
    assert_equal :ok, p.status
    assert_empty p.warnings
  end

  test "expired medical certificate is only a warning" do
    sell_course_to(@bob, end_date: Date.current + 30)
    p = policy(@bob)
    assert_equal :warning, p.status
    assert_includes p.warnings, "Certificato Medico scaduto o mancante."
  end

  test "certificate not required means no warning" do
    @yoga_discipline.update!(requires_medical_certificate: false)
    sell_course_to(@bob, end_date: Date.current + 30)
    assert_equal :ok, policy(@bob).status
  end

  test "subscription expiring within a week warns" do
    sell_course_to(@alice, end_date: Date.current + 3)
    assert_includes policy(@alice).warnings, "Abbonamento in scadenza tra 3 giorni."
  end



  test "no warnings are evaluated when there are errors" do
    p = policy(@bob)
    assert_equal :error, p.status
    assert_empty p.warnings
  end

  private
    def sell_course_to(member, end_date: nil)
      grant_membership_to(member)
      Subscription.create!(member:, product: @course, start_date: Date.current - 1, end_date: end_date || Date.current + 30)
    end
end
