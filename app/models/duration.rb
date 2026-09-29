Duration = Data.define(:start_date, :end_date) do
  def self.for(product, preference_date = Date.current)
    new(**calculate(product, preference_date.to_date))
  end

  private_class_method def self.calculate(product, date)
    product.associative? ? associative(date) : institutional(product, date)
  end

  # da agosto la quota copre anche l'anno sportivo successivo: per un solo mese sarebbe uno spreco
  private_class_method def self.associative(date)
    year = SportYear.new(date)
    { start_date: date, end_date: (year.last_month? ? year.next : year).end_date }
  end

  # mesi e semestri restano nell'anno sportivo; trimestri e anno a scorrimento no
  private_class_method def self.institutional(product, date)
    case product.duration_days
    when 30       then calendar_aligned(date, 1)
    when 90       then calendar_aligned(date, 3, enforce_sport_year: false)
    when 180      then calendar_aligned(date, 6)
    when 365, 366 then rolling_annual(date)
    else               days_pure(product.duration_days, date)
    end
  end

  private_class_method def self.rolling_annual(date)
    { start_date: date, end_date: date.advance(years: 1).yesterday }
  end

  private_class_method def self.calendar_aligned(date, months, enforce_sport_year: true)
    start_date      = date.beginning_of_month
    theoretical_end = start_date.advance(months: months - 1).end_of_month
    end_date        = enforce_sport_year ?
                        [ theoretical_end, SportYear.end_date_for(start_date) ].min :
                        theoretical_end
    { start_date:, end_date: }
  end

  private_class_method def self.days_pure(days, date)
    { start_date: date, end_date: [ date.advance(days: days).yesterday, SportYear.end_date_for(date) ].min }
  end
end
