class SportYear
  attr_reader :year

  def initialize(date = Date.current)
    @date = date
    @year = (@date.month >= 9 ? @date.year : @date.year - 1)
  end

  def start_date
    Date.new(@year, 9, 1)
  end

  def end_date
    Date.new(@year + 1, 8, 31)
  end

  def to_s
    "#{@year}/#{@year + 1}"
  end

  def next = SportYear.new(end_date + 1)

  # agosto chiude l'anno: una quota venduta ora deve valere anche per il successivo
  def last_month?(date = @date) = date.month == 8

  def self.current
    new(Date.current)
  end

  def self.end_date_for(date)
    new(date).end_date
  end
end
