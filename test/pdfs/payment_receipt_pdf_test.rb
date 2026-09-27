require "test_helper"

class PaymentReceiptPdfTest < ActiveSupport::TestCase
  # registra testi e tabelle; prawn-table arriva come estensione, quindi anche la spia
  # (ogni sottoclasse copia la lista alla definizione: va toccata quella della ricevuta)
  module Spy
    def printed = (@printed ||= [])
    def text(string, *, **) = printed << string.to_s && super
    def table(data, *, **, &) = printed.concat(data.flatten.map(&:to_s)) && super
  end

  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    PaymentReceiptPdf.extensions.unshift(Spy)
  end

  teardown { PaymentReceiptPdf.extensions.delete(Spy) }

  def printed_for(sale) = PaymentReceiptPdf.new(sale).printed.join("\n")

  test "renders a valid pdf" do
    pdf = PaymentReceiptPdf.new(sell!(member: @member, product: products(:yoga_monthly))).render
    assert pdf.start_with?("%PDF")
  end

  test "cash sale shows the receipt number" do
    sale = sell!(member: @member, product: products(:yoga_monthly))
    assert_match "RICEVUTA N. #{sale.receipt_code}", printed_for(sale)
  end

  test "non cash sale is a summary, not a receipt" do
    sale = sell!(member: @member, product: products(:yoga_monthly), payment_method: :bank_transfer)
    text = printed_for(sale)
    assert_match "RIEPILOGO", text
    assert_no_match "RICEVUTA N.", text
    assert_match "Pagamento: Bonifico", text
  end

  test "payment method is in italian" do
    sale = sell!(member: @member, product: products(:yoga_monthly), payment_method: :credit_card)
    assert_match "Pagamento: Carta / POS", printed_for(sale)
  end

  test "product name is frozen at sale time" do
    sale = sell!(member: @member, product: products(:yoga_monthly))
    products(:yoga_monthly).update!(name: "Yoga Rinominato")

    text = printed_for(sale.reload)
    assert_match "Quota Istituzionale: Yoga Mensile", text
    assert_no_match "Rinominato", text
  end

  test "renders names outside windows-1252" do
    @member.update_columns(first_name: "Ștefan", last_name: "Łukasiewicz")
    sale = sell!(member: @member.reload, product: products(:yoga_monthly))

    assert PaymentReceiptPdf.new(sale).render.start_with?("%PDF")
    assert_match "Ștefan Łukasiewicz", printed_for(sale)
  end

  test "renders product and gym names outside windows-1252" do
    GymProfile.current.update!(name: "ASD Șoimii", address_line_1: "Ulica Łódzka 1")
    sale = sell!(member: @member, product: products(:yoga_monthly))
    sale.update_columns(product_name_snapshot: "Joga Ćwiczenia")

    text = printed_for(sale.reload)
    assert_match "ASD Șoimii", text
    assert_match "Joga Ćwiczenia", text
  end

  test "renders every text style with the embedded font" do
    @member.update_columns(fiscal_code: nil)
    pdf = PaymentReceiptPdf.new(sell!(member: @member.reload, product: products(:yoga_monthly)))

    assert_equal "LiberationSans", pdf.font.family
    assert_match "C.F. Non disponibile", pdf.printed.join("\n")
    assert pdf.render.start_with?("%PDF")
  end

  test "shows subscription validity and amount" do
    sale = sell!(member: @member, product: products(:yoga_monthly), amount: 20)
    sub = sale.subscription
    text = printed_for(sale)

    assert_match "Validità: #{I18n.l(sub.start_date)} - #{I18n.l(sub.end_date)}", text
    assert_match "20,00", text
  end
end
