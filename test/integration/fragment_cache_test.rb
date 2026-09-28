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

  test "member rows refresh on new subscriptions, product renames and role" do
    with_fragment_caching do
      sign_in_as(users(:staff))
      get members_path
      assert_no_match "Nuoto Libero", response.body

      nuoto = Product.create!(name: "Nuoto Libero", price_cents: 0, duration_days: 30)
      travel 1.second
      Subscription.create!(member: @member, product: nuoto, start_date: Date.current, end_date: Date.current + 20)
      get members_path
      assert_match "Nuoto Libero", response.body

      travel 1.second
      nuoto.update!(name: "Nuoto Serale")
      get members_path
      assert_match "Nuoto Serale", response.body

      assert_select "a[data-turbo-method=delete][href='#{member_path(@member)}']", count: 0
      sign_in_as(users(:admin))
      get members_path
      assert_select "a[data-turbo-method=delete][href='#{member_path(@member)}']"
    end
  end

  test "kiosk cards follow payments and certificates, cold or warm cache" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    grant_membership_to(@member)
    subscription = Subscription.create!(member: @member, product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    Attendance.create!(member: @member, discipline: disciplines(:yoga), marked_by: users(:kiosk))

    with_fragment_caching do
      sign_in_as(users(:kiosk))
      2.times do
        get kiosk_discipline_path(disciplines(:yoga))
        assert_select "#attendances .card", text: /Da saldare/
      end

      Sale.create!(member: @member, product: course, user: users(:staff), subscription:, payment_method: :cash)
      get kiosk_discipline_path(disciplines(:yoga))
      assert_select "#attendances .card", text: /Saldato/

      @member.update_column(:medical_certificate_expiry, Date.yesterday) # nessun touch: conta la chiave della posizione
      get kiosk_discipline_path(disciplines(:yoga))
      assert_select "#attendances .card", text: /Cert. scaduto/
    end
  end

  test "kiosk pending cards follow the standing, cold or warm cache" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    Subscription.create!(member: @member, product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month,
                         agreed_price_cents: 0)
    memberships = Subscription.where(id: @member.subscriptions.memberships.select(:id))

    with_fragment_caching do
      sign_in_as(users(:kiosk))
      get kiosk_discipline_path(disciplines(:yoga))
      assert_select "#pending_members .card", text: /Saldato/

      memberships.update_all(discarded_at: Time.current) # nessun touch del socio: conta la chiave della posizione
      get kiosk_discipline_path(disciplines(:yoga))
      assert_select "#pending_members .card", text: /Quota mancante/
    end
  end

  test "dashboard rows of who is to regularize follow member and discipline renames" do
    Attendance.create!(member: members(:bob), discipline: disciplines(:yoga), marked_by: users(:kiosk))

    with_fragment_caching do
      sign_in_as(users(:staff))
      get root_path
      assert_select "#unenrolled_attendances", text: /Bob Bianchi\s*Yoga/

      travel 1.second
      members(:bob).update!(first_name: "Roberto")
      disciplines(:yoga).update!(name: "Yoga Flow")
      get root_path
      assert_select "#unenrolled_attendances", text: /Roberto Bianchi\s*Yoga Flow/
    end
  end

  test "kiosk register reads each column of cards at once" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    Subscription.create!(member: members(:bob), product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    Attendance.create!(member: @member, discipline: disciplines(:yoga), marked_by: users(:kiosk))

    with_fragment_caching do
      sign_in_as(users(:kiosk))
      get kiosk_discipline_path(disciplines(:yoga))

      reads = 0
      ActiveSupport::Notifications.subscribed(->(*) { reads += 1 }, /\Acache_read(_multi)?\.active_support\z/) do
        get kiosk_discipline_path(disciplines(:yoga))
      end
      assert_equal 2, reads, "una lettura per 'Da smarcare' e una per 'Nel registro'"
      assert_select "#pending_members h3", text: "Bob Bianchi"
      assert_select "#attendances h3", text: "Alice Allevi"
    end
  end

  test "kiosk home reads every discipline card at once and follows renames" do
    with_fragment_caching do
      sign_in_as(users(:kiosk))
      get kiosk_root_path
      assert_select "h3", text: /Yoga/

      reads = []
      counter = ->(*, payload) { reads << payload[:key] }
      ActiveSupport::Notifications.subscribed(counter, "cache_read_multi.active_support") { get kiosk_root_path }
      assert_equal 1, reads.size, "una sola lettura per tutte le card"

      travel 1.second
      disciplines(:yoga).update!(name: "Yoga Flow")
      get kiosk_root_path
      assert_select "h3", text: /Yoga Flow/
    end
  end
end
