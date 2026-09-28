require "test_helper"

class SalesHelperTest < ActionView::TestCase
  include IconsHelper

  test "payment method options are in italian and match the enum" do
    options = payment_method_options
    assert_equal Sale.payment_methods.keys.sort, options.map(&:last).sort
    assert_includes options, [ "Contanti", "cash" ]
  end

  test "payment badge falls back to other for unknown methods" do
    assert_match "Contanti", payment_method_badge(:cash)
    assert_match "Altro", payment_method_badge("bitcoin")
  end

  test "grouped product options by discipline, uncategorized first" do
    link!(products(:yoga_monthly), disciplines(:yoga), disciplines(:sala_pesi))

    groups = grouped_product_options.to_h
    assert_equal "Quote e Varie", grouped_product_options.first.first
    assert_includes groups["Quote e Varie"], [ "Quota Associativa 2025", products(:annual_membership).id ]
    assert_includes groups["Yoga"], [ "Yoga Mensile", products(:yoga_monthly).id ]
    assert_includes groups["Sala Pesi"], [ "Yoga Mensile", products(:yoga_monthly).id ]
    assert_not groups.values.flatten.include?(products(:pilates_legacy).id)
  end

  test "archived disciplines do not create groups" do
    link!(products(:yoga_monthly), disciplines(:pilates_old))
    assert_not grouped_product_options.to_h.key?("Pilates")
  end
end
