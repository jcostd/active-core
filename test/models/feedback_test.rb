require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  setup do
    @user = users(:staff)
  end

  test "requires a message, not a user: the system writes too" do
    feedback = Feedback.new
    assert_not feedback.valid?
    assert_includes feedback.errors[:message], "non può essere lasciato in bianco"

    assert Feedback.new(message: "Controllo del database fallito").valid?
  end
end
