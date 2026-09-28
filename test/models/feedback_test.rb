require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  setup do
    @user = users(:staff)
  end

  test "requires message and user" do
    feedback = Feedback.new
    assert_not feedback.valid?

    assert_includes feedback.errors[:message], "non può essere lasciato in bianco"
    assert_includes feedback.errors[:user], "deve esistere"
  end
end
