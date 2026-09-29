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

  test "a discarded member cannot be marked" do
    assert_no_difference -> { Attendance.count } do
      post kiosk_discipline_attendances_path(@discipline, member_id: members(:deleted).id)
    end
    assert_response :not_found
  end

  test "an unknown member cannot be marked" do
    post kiosk_discipline_attendances_path(@discipline, member_id: 0)
    assert_response :not_found
  end

  test "discarded discipline is not reachable" do
    get kiosk_discipline_member_searches_path(disciplines(:pilates_old), query: "Alice")
    assert_response :not_found

    get kiosk_discipline_path(disciplines(:pilates_old))
    assert_response :not_found

    post kiosk_discipline_attendances_path(disciplines(:pilates_old), member_id: members(:alice).id)
    assert_response :not_found
  end

  test "a kept member is marked" do
    assert_difference -> { Attendance.count } do
      post kiosk_discipline_attendances_path(@discipline, member_id: members(:alice).id)
    end
    assert_redirected_to kiosk_discipline_path(@discipline)
  end

  test "a member archived after the mark stays in the register" do
    post kiosk_discipline_attendances_path(@discipline, member_id: members(:alice).id)
    members(:alice).discard!

    get kiosk_discipline_path(@discipline)
    assert_select "#attendances", text: /Alice Allevi/
    assert_select "#pending_members", text: /Alice Allevi/, count: 0
  end
end
