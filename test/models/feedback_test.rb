require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  setup do
    @user = users(:staff)
  end

  test "valid feedback creation with full details" do
    feedback = Feedback.new(
      user: @user,
      message: "Il tasto salva non funziona su iPad",
      page_url: "/members/10/edit",
      browser_info: "Safari Mobile 15.0",
      admin_notes: "Verificare logs del server"
    )

    assert feedback.valid?
    assert feedback.save

    assert_equal "/members/10/edit", feedback.page_url
    assert_equal "Safari Mobile 15.0", feedback.browser_info
    assert_equal "Verificare logs del server", feedback.admin_notes
  end

  test "requires message and user" do
    feedback = Feedback.new
    assert_not feedback.valid?

    assert_includes feedback.errors[:message], "non può essere lasciato in bianco"
    assert_includes feedback.errors[:user], "deve esistere"
  end

  test "sets default status to pending" do
    feedback = Feedback.create!(
      user: @user,
      message: "Ho un problema"
    )

    assert feedback.pending?
    assert_equal "pending", feedback.status
  end

  test "status workflow works correctly via enum" do
    feedback = Feedback.create!(
      user: @user,
      message: "Bug critico"
    )

    # Cambio stato: In lavorazione
    feedback.in_progress!
    assert feedback.in_progress?
    assert_not feedback.pending?

    # Cambio stato: Risolto
    feedback.resolved!
    assert feedback.resolved?

    # Verifica persistenza DB
    assert_equal 2, feedback.reload.status_before_type_cast # 2 = resolved
  end
end
