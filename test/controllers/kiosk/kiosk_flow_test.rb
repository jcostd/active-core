require "test_helper"

class KioskFlowTest < ActionDispatch::IntegrationTest
  setup do
    @alice = members(:alice)
    @yoga = disciplines(:yoga)
    grant_membership_to(@alice)
    @course = link!(products(:yoga_monthly), @yoga)
    sign_in_as(users(:staff))
  end

  test "kiosk home lists kept disciplines" do
    get kiosk_root_path
    assert_response :success
    assert_match "Yoga", response.body
    assert_no_match ">Pilates<", response.body
  end

  test "discipline page lists subscribed members to check in" do
    sell!(member: @alice, product: @course)

    get kiosk_discipline_path(@yoga)
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :pending)}"
  end

  test "checked in member moves to the room list" do
    sell!(member: @alice, product: @course)
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    get kiosk_discipline_path(@yoga)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :pending)}", count: 0
    assert_select "##{ActionView::RecordIdentifier.dom_id(AccessLog.last)}"
  end

  test "flash reflects the access outcome" do
    sell!(member: @alice, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 30)
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)
    assert_equal "Check-in registrato per Alice", flash[:success]

    post kiosk_discipline_access_logs_path(@yoga, member_id: members(:bob).id)
    assert_match "Check-in FORZATO per Bob", flash[:error]
  end

  test "double tap shows an error and records nothing" do
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    assert_no_difference -> { AccessLog.count } do
      post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)
    end
    assert_match "Impossibile registrare il check-in", flash[:error]
  end


  test "kiosk has no way to cancel a check-in" do
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    get kiosk_discipline_path(@yoga)
    assert_select "form[method=post] input[name=_method][value=delete]", count: 0
    assert_raises(NameError) { kiosk_discipline_access_log_path(@yoga, AccessLog.last) }
  end

  test "kiosk search returns check-in buttons" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Ali")
    assert_select "form[action='#{kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)}']"
  end
end
