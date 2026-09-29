require "test_helper"

class FiscalLockableTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    @user = users(:staff)
    @product = products(:annual_membership)

    # Creiamo una vendita già finalizzata (con numero ricevuta)
    @sale = Sale.create!(
      member: @member,
      user: @user,
      product: @product,
      sold_on: Date.current,
      payment_method: :cash,
      amount_cents: 1000,
      receipt_number: 100,
      receipt_year: 2024,
      receipt_sequence: "A",
      subscription_attributes: {}
    )
  end

  test "allows updating non-fiscal attributes" do
    # Modifichiamo la data di vendita o note (se esistessero)
    # Nota: cambiare la data di vendita non cambia il numero ricevuta già emesso
    @sale.sold_on = Date.yesterday

    assert @sale.save, "Dovrebbe permettere modifiche a campi non bloccati"
  end

  test "prevents changing receipt_number once set" do
    original_number = @sale.receipt_number

    # Tentativo di manomissione
    @sale.receipt_number = 999

    assert_not @sale.save, "Non dovrebbe salvare la modifica al numero ricevuta"
    assert_includes @sale.errors[:receipt_number], "è un dato fiscale e non può essere modificato dopo l'emissione"

    # Verifica DB intatto
    assert_equal original_number, @sale.reload.receipt_number
  end

  test "prevents changing receipt_year once set" do
    @sale.receipt_year = 2020

    assert_not @sale.save
    assert @sale.errors[:receipt_year].present?
  end

  test "allows setting receipt number if it was nil (first assignment)" do
    # Creiamo una vendita "in bozza" o carta di credito (senza numero)
    pending_sale = Sale.create!(
      member: @member,
      user: @user,
      product: @product,
      sold_on: Date.current,
      payment_method: :credit_card, # Assumiamo che CC non generi subito numero o sia nil
      subscription_attributes: {}
    )

    # Simuliamo che diventi contanti o assegnazione manuale
    pending_sale.receipt_number = 500
    pending_sale.receipt_year = 2025

    assert pending_sale.save, "Dovrebbe permettere la prima assegnazione (da nil a valore)"
  end
end
