# posizione di un socio in una disciplina per un mese: cosa vede l'istruttore accanto al nome.
# In memoria: chi la mostra precarica gli abbonamenti con vendite, prodotto e discipline.
class Standing
  LABELS = { not_enrolled: "Non iscritto", no_membership: "Quota mancante", due: "Da saldare", paid: "Saldato" }.freeze

  attr_reader :member, :discipline, :month

  def initialize(member:, discipline:, month: Date.current)
    @member, @discipline, @month = member, discipline, month.to_date.beginning_of_month
  end

  def key
    @key ||= if enrollments.empty?
      :not_enrolled
    elsif discipline.requires_membership? && !member.membership_valid?(day)
      :no_membership
    elsif enrollments.any? { it.amount_due.positive? }
      :due
    else
      :paid
    end
  end

  def label = LABELS.fetch(key)

  def certificate_missing?
    discipline.requires_medical_certificate? && !member.medical_certificate_valid?(day)
  end

  # error: da regolarizzare in segreteria; warning: da sollecitare
  def tone
    if key.in?(%i[not_enrolled no_membership]) then :error
    elsif key == :due || certificate_missing? then :warning
    else :ok
    end
  end

  def enrollments
    @enrollments ||= member.enrollments_in(discipline, during: month.all_month)
  end

  private
    # il mese in corso si guarda a oggi, quelli chiusi al loro ultimo giorno
    def day = [ month.end_of_month, Date.current ].min
end
