require "test_helper"

class AccessLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @log = AccessLog.create!(member: members(:bob), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    sign_in_as(users(:admin))
  end

  test "index filters by status and discipline" do
    get access_logs_path(status: "error", discipline_id: disciplines(:yoga).id)
    assert_response :success
    assert_match "Bob Bianchi", response.body

    get access_logs_path(status: "ok")
    assert_no_match "Bob Bianchi", response.body
  end

  test "admin cancels an entry" do
    delete access_log_path(@log)
    assert_redirected_to access_logs_path
    assert_not AccessLog.exists?(@log.id)
  end
end
