require "test_helper"

class FilterFormsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:admin)) }

  test "drawer filters use italian labels" do
    get sales_path
    assert_select "#filter-form select[name=payment_method] option", text: "Contanti"
    assert_select "#filter-form select[name=payment_method] option", text: /Credit card/, count: 0

    get access_logs_path
    assert_select "#filter-form select[name=status] option", text: "Consentito"
    assert_select "#filter-form select[name=status] option", text: "Warning", count: 0
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
    get access_logs_path
    assert_select "select[name=sort] option[value=date_asc]", text: "Meno recenti"
    assert_select "select[name=sort] option[selected][value=date_desc]"
  end
end
