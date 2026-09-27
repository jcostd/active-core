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

  test "active filter chips reuse the labels of their select" do
    form_with(url: "/") do |form|
      filter_select form, :membership_status, member_membership_filters, label: "Stato Tesseramento", blank: "Tutti"
      filter_select form, :state, [ [ "Valide", "active" ], [ "Annullate", "discarded" ] ], label: "Stato Ricevuta", blank: "Tutte"
      filter_select form, :product_id, [ [ "Yoga", [ [ "Yoga Mensile", products(:yoga_monthly).id ] ] ] ], label: "Prodotto", blank: "Tutti"
    end

    assert_equal "Stato Tesseramento", humanize_filter_key(:membership_status)
    assert_equal "Quota scaduta", humanize_filter_value(:membership_status, "expired")
    assert_equal "Valide", humanize_filter_value(:state, "active")
    assert_equal "Annullate", humanize_filter_value("state", "discarded")
    assert_equal "Yoga Mensile", humanize_filter_value(:product_id, products(:yoga_monthly).id.to_s)
  end

  test "filters without a select still get italian names" do
    assert_equal "Ricerca", humanize_filter_key(:query)
    assert_equal "mario", humanize_filter_value(:query, "mario")
    assert_equal "Mese", humanize_filter_key(:month)
    assert_equal "Agosto 2026", humanize_filter_value(:month, "2026-08")
    assert_equal "boh", humanize_filter_value(:month, "boh")
  end
end
