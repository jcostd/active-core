require "test_helper"

class FilterFormsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:admin)) }

  test "drawer filters use italian labels" do
    get sales_path
    assert_select "#filter-form select[name=payment_method] option", text: "Contanti"
    assert_select "#filter-form select[name=payment_method] option", text: /Credit card/, count: 0

    get discipline_members_path(disciplines(:yoga))
    assert_select "#filter-form select[name=seen] option", text: "Visti dall'istruttore"
    assert_select "#filter-form select[name=seen] option", text: "Yes", count: 0
  end

  test "active filter chips speak italian on every page" do
    { members_path(membership_status: "expired") => "Quota scaduta",
      sales_path(state: "active") => "Valide",
      sales_path(state: "discarded", period: "last_month") => "Mese Scorso",
      discipline_members_path(disciplines(:yoga), seen: "no") => "Non visti",
      users_path(role: "kiosk") => "Kiosk",
      discipline_members_path(disciplines(:yoga), membership_status: "missing") => "Mai tesserato" }.each do |path, label|
      get path
      assert_select "#active_filters .badge strong", text: label
    end
  end

  test "a chip links to the same page without that filter; clearing keeps the sort and the month" do
    path = discipline_members_path(disciplines(:yoga))
    get discipline_members_path(disciplines(:yoga), month: "2026-08", sort: "name_desc", seen: "no", med_cert: "expired", page: 2)

    assert_select "#active_filters a[href=?]", "#{path}?med_cert=expired&month=2026-08&sort=name_desc"
    assert_select "#active_filters a[href=?]", "#{path}?month=2026-08&seen=no&sort=name_desc"
    assert_select "#active_filters a[href=?]", "#{path}?month=2026-08&sort=name_desc", text: "Azzera filtri"
  end

  test "sales state chip is not mislabelled" do
    get sales_path(state: "active")
    assert_select "#active_filters .badge strong", text: "Archiviati", count: 0
  end

  test "selected filter is kept after reload" do
    get members_path(med_cert: "expired")
    assert_select "select[name=med_cert] option[selected][value=expired]"
  end

  test "each filter select has a legend" do
    get sales_path
    selects = css_select("dialog select")
    assert_operator selects.size, :>=, 5
    assert_equal selects.size, css_select("dialog fieldset.fieldset > legend.fieldset-legend").size
  end

  test "pages without drawer have no filter button" do
    get products_path
    assert_select "#filter-form input[name=query]"
    assert_select "#filter-form [data-action='drawer#open']", count: 0
    assert_select "dialog", count: 0
  end

  test "custom sort options are rendered" do
    get discipline_members_path(disciplines(:yoga))
    assert_select "select[name=sort] option[value=name_desc]", text: "Nome: Z-A"
    assert_select "select[name=sort] option[selected][value=name_asc]"
  end
end
