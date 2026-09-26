require "test_helper"

class FragmentCacheTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @subscription = @member.subscriptions.kept.find_by!(end_date: Date.current.end_of_year)
  end

  test "subscription rows are not shared between admin and staff" do
    with_fragment_caching do
      sign_in_as(users(:admin))
      get member_subscriptions_path(@member)
      assert_select "a[href='#{edit_subscription_path(@subscription)}']"

      sign_out
      sign_in_as(users(:staff))
      get member_subscriptions_path(@member)
      assert_select "a[href='#{edit_subscription_path(@subscription)}']", count: 0
    end
  end

  test "subscription rows refresh when the day changes" do
    with_fragment_caching do
      sign_in_as(users(:admin))
      get member_subscriptions_path(@member)
      before = css_select("#" + ActionView::RecordIdentifier.dom_id(@subscription)).to_s

      travel 1.day
      sign_in_as(users(:admin))
      get member_subscriptions_path(@member)
      after = css_select("#" + ActionView::RecordIdentifier.dom_id(@subscription)).to_s

      assert_not_equal before, after
    end
  end

  test "reverse button disappears after the reversal window" do
    sale = Sale.create!(member: @member, product: products(:yoga_monthly), user: users(:staff), sold_on: Date.current,
                        amount: 10, subscription_attributes: { member: @member, product: products(:yoga_monthly) })

    with_fragment_caching do
      sign_in_as(users(:admin))
      get sales_path
      assert_select "a[data-turbo-method=delete][href='#{sale_path(sale)}']"

      travel Sale::ADMIN_REVERSAL_WINDOW + 1.minute
      sign_in_as(users(:admin))
      get sales_path
      assert_select "a[data-turbo-method=delete][href='#{sale_path(sale)}']", count: 0
    end
  end

  test "renamed member shows up in cached dashboard rows" do
    Sale.create!(member: @member, product: products(:yoga_monthly), user: users(:staff), sold_on: Date.current,
                 amount: 10, subscription_attributes: { member: @member, product: products(:yoga_monthly) })

    with_fragment_caching do
      sign_in_as(users(:admin))
      get root_path
      assert_match "Alice Allevi", response.body

      travel 1.second
      # istanza nuova: quella della vendita ha un touch differito che nei test non viene mai confermato
      Member.find(@member.id).update!(first_name: "Alicia")
      get root_path
      assert_match "Alicia Allevi", response.body
    end
  end

  test "user rows are not shared between admins" do
    other_admin = users(:staff_two)
    other_admin.update!(role: :admin)

    with_fragment_caching do
      sign_in_as(users(:admin))
      get users_path
      assert_select "a[data-turbo-method=delete][href='#{user_path(other_admin)}']"
      assert_select "a[data-turbo-method=delete][href='#{user_path(users(:admin))}']", count: 0

      sign_in_as(other_admin)
      get users_path
      assert_select "a[data-turbo-method=delete][href='#{user_path(other_admin)}']", count: 0, message: "nessuno archivia sé stesso"
      assert_select "a[data-turbo-method=delete][href='#{user_path(users(:admin))}']"
    end
  end
end
