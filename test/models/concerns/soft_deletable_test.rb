require "test_helper"

class SoftDeletableTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
  end

  test "discard! sets the discarded_at timestamp" do
    assert_nil @member.discarded_at
    assert_not @member.discarded?

    @member.discard!

    assert @member.discarded_at.present?
    assert @member.discarded?
  end

  test "undiscard! removes the timestamp" do
    @member.discard!
    assert @member.discarded?

    @member.undiscard!

    assert_nil @member.discarded_at
    assert_not @member.discarded?
  end

  test "scopes filter correctly" do
    # Alice è attiva
    # Bob è attivo
    # Deleted è cancellato (nelle fixtures)

    kept_count = Member.kept.count
    discarded_count = Member.discarded.count

    # Cancelliamo Alice
    @member.discard!

    assert_equal kept_count - 1, Member.kept.count
    assert_equal discarded_count + 1, Member.discarded.count
  end

  test "discard runs model callbacks" do
    user = users(:staff)
    user.sessions.create!
    user.discard!
    assert_empty user.sessions.reload
  end

  test "discard and undiscard can be repeated safely" do
    @member.discard!
    first = @member.discarded_at
    travel 1.minute
    @member.undiscard!
    @member.discard!
    assert_operator @member.discarded_at, :>, first
  end
end
