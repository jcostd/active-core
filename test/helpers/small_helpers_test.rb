require "test_helper"

class SmallHelpersTest < ActionView::TestCase
  include IconsHelper, UiHelper, MembersHelper, ProductsHelper, StandingsHelper, FiltersHelper

  test "product category" do
    assert_match "Q. Associativa", product_category_badge(products(:annual_membership))
    assert_match "Q. Istituzionale", product_category_badge(products(:yoga_monthly))
  end

  test "standing styles cover every key and tone" do
    assert_equal Standing::LABELS.keys.sort, StandingsHelper::STANDING_BADGES.keys.sort
    assert_equal %i[error ok warning], StandingsHelper::STANDING_CARDS.keys.sort
  end

  test "standing badges name the standing and the certificate" do
    standing = Struct.new(:key, :label, :certificate_missing?)

    html = standing_badges(standing.new(:paid, "Saldato", false))
    assert_match "Saldato", html
    assert_match "badge-success", html
    assert_no_match "Cert.", html

    html = standing_badges(standing.new(:not_enrolled, "Non iscritto", true))
    assert_match "badge-error", html
    assert_match "Cert. scaduto", html
  end

  test "member badges" do
    grant_membership_to(members(:alice))
    assert_match "Quota valida", member_status_badges(members(:alice))
    html = member_status_badges(members(:bob))
    assert_match "Quota scaduta", html
    assert_match "Cert. Medico", html
  end

  test "member filter options" do
    assert_equal %w[active expired missing], member_membership_filters.map(&:last)
    assert_equal %w[valid expired missing], member_med_cert_filters.map(&:last)
  end

  test "active filter chips reuse the labels of their select" do
    filter_select :membership_status, member_membership_filters, label: "Stato Tesseramento", blank: "Tutti"
    filter_select :state, [ [ "Valide", "active" ], [ "Annullate", "discarded" ] ], label: "Stato Ricevuta", blank: "Tutte"
    grouped = filter_select :product_id, [ [ "Yoga", [ [ "Yoga Mensile", products(:yoga_monthly).id ] ] ] ], label: "Prodotto", blank: "Tutti"
    assert_match %(<optgroup label="Yoga">), grouped

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
