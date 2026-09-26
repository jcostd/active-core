require "test_helper"

class SmallHelpersTest < ActionView::TestCase
  include IconsHelper, UiHelper, MembersHelper, ProductsHelper, AccessLogsHelper, FiltersHelper

  test "product category" do
    assert_match "Q. Associativa", product_category_badge(products(:annual_membership))
    assert_match "Quota Istituzionale", product_category_text(products(:yoga_monthly))
  end

  test "access log styles cover every enum value" do
    AccessLog.statuses.each_key do |status|
      log = AccessLog.new(status:)
      assert access_log_status_badge(log).present?, status
      assert access_log_status_icon(log).present?, status
    end
    assert_match "Negato", access_log_status_badge(AccessLog.new(status: :error))
    assert_equal "Accesso Generico", access_log_activity_name(AccessLog.new)
  end

  test "member badges" do
    grant_membership_to(members(:alice))
    assert_match "Tessera Attiva", member_status_badges(members(:alice))
    html = member_status_badges(members(:bob))
    assert_match "Tessera Scaduta", html
    assert_match "Cert. Medico", html
  end

  test "member filter options" do
    assert_equal %w[active expired missing], member_membership_filters.map(&:last)
    assert_equal %w[valid expired missing], member_med_cert_filters.map(&:last)
  end

  test "filter keys and values are humanized" do
    assert_equal "Corso", humanize_filter_key(:product_id)
    assert_equal "Yoga Mensile", humanize_filter_value(:product_id, products(:yoga_monthly).id)
    assert_equal "Sconosciuto", humanize_filter_value(:product_id, 0)
    assert_equal "Archiviati", humanize_filter_value(:state, "discarded")
  end
end
