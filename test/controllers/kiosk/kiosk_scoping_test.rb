require "test_helper"

class KioskScopingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:staff))
    @discipline = disciplines(:open_day)
  end

  test "search skips discarded members" do
    get kiosk_discipline_member_searches_path(@discipline, query: "Carlo")
    assert_response :success
    assert_no_match "Cancellato", response.body
    assert_match "Nessun socio trovato", response.body

    get kiosk_discipline_member_searches_path(@discipline, query: "Alice")
    assert_select "button", text: /Alice Allevi/
  end

  test "check-in of a discarded member is not found" do
    assert_no_difference -> { AccessLog.count } do
      post kiosk_discipline_access_logs_path(@discipline, member_id: members(:deleted).id)
    end
    assert_response :not_found
  end

  test "discarded discipline is not reachable" do
    get kiosk_discipline_member_searches_path(disciplines(:pilates_old), query: "Alice")
    assert_response :not_found

    post kiosk_discipline_access_logs_path(disciplines(:pilates_old), member_id: members(:alice).id)
    assert_response :not_found
  end

  test "check-in of a kept member is recorded" do
    assert_difference -> { AccessLog.count } do
      post kiosk_discipline_access_logs_path(@discipline, member_id: members(:alice).id)
    end
    assert_redirected_to kiosk_discipline_path(@discipline)
  end
end
