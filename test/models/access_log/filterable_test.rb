require "test_helper"

class AccessLog::FilterableTest < ActiveSupport::TestCase
  setup do
    grant_membership_to(members(:alice))
    link!(products(:yoga_monthly), disciplines(:open_day))
    sell!(member: members(:alice), product: products(:yoga_monthly))
    @ok  = AccessLog.create!(member: members(:alice), discipline: disciplines(:open_day), checkin_by_user: users(:staff))
    @err = AccessLog.create!(member: members(:bob), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
  end

  test "status reflects the access policy" do
    assert @err.error?
    assert_not @ok.error?
  end

  test "filters by status, discipline and member name" do
    assert_equal [ @err ], AccessLog.apply_filters(status: "error").to_a
    assert_equal [ @ok ], AccessLog.apply_filters(discipline_id: disciplines(:open_day).id).to_a
    assert_equal [ @err ], AccessLog.apply_filters(query: "Bianchi").to_a
  end

  test "sort ascending by entry time" do
    travel 1.minute
    later = AccessLog.create!(member: members(:alice), discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    assert_equal later, AccessLog.apply_filters(sort: "date_desc").first
    assert_equal later, AccessLog.apply_filters(sort: "date_asc").last
  end
end
