require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:staff)) }

  test "new prefills the current page" do
    get new_feedback_path(current_page: "/members")
    assert_response :success
    assert_match "/members", response.body
  end

  test "create stores message, page and browser" do
    assert_difference -> { users(:staff).feedbacks.count } do
      post feedbacks_path, params: { feedback: { message: "Il bottone non va", page_url: "/sales/new" } },
                           headers: { "User-Agent" => "iPad Safari", "Referer" => "http://www.example.com/sales/new" }
    end
    feedback = Feedback.last
    assert_equal [ "/sales/new", "iPad Safari", "pending" ], [ feedback.page_url, feedback.browser_info, feedback.status ]
    assert_equal "Segnalazione inviata. Grazie per il tuo aiuto!", flash[:notice]
  end

  test "empty message is rejected" do
    assert_no_difference -> { Feedback.count } do
      post feedbacks_path, params: { feedback: { message: "" } }
    end
    assert_response :unprocessable_entity
  end
end
