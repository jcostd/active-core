class RenewalCalculator
  GRACE_PERIOD_DAYS = 30

  def initialize(member, product, reference_date = Date.current)
    @member = member
    @product = product
    @reference_date = reference_date.to_date
  end

  # Ritorna SOLO una Date (la data di partenza suggerita)
  def call
    return @reference_date unless @member && @product

    last_sub = @member.subscriptions.kept
                      .where(product: @product)
                      .order(end_date: :desc)
                      .first

    # Se non ha abbonamenti precedenti, parte dalla data contabile (oggi)
    return @reference_date unless last_sub

    continuity_date = last_sub.end_date + 1.day
    gap_days = (@reference_date - continuity_date).to_i

    # Se gap_days è negativo (anticipo) o nel periodo di grazia (0..30), uniamo l'abbonamento.
    if gap_days <= GRACE_PERIOD_DAYS
      continuity_date
    else
      # Buco troppo grande, si riparte da zero dalla data contabile
      @reference_date
    end
  end
end
