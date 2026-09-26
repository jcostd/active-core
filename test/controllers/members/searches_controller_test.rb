require "test_helper"

class Members::SearchesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:staff)) }

  test "finds kept members" do
    get members_searches_path(query: "Alice")
    assert_response :success
    assert_match "Alice", response.body
  end

  test "skips discarded members" do
    get members_searches_path(query: "Carlo")
    assert_no_match "Cancellato", response.body
  end

  test "blank query returns nothing" do
    get members_searches_path(query: "")
    assert_no_match "Alice", response.body
  end
end
