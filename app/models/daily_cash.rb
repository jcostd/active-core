class DailyCash
  SPLIT_HOUR = 14
  attr_reader :date

  # Aggiungiamo il parametro opzionale 'sales'
  def initialize(date = Date.current, sales: nil)
    @date = date
    @preloaded_sales = sales # Può essere nil o un Array di Sale
  end

  def self.current
    new(Date.current)
  end

  def self.for(date, sales: nil)
    new(date, sales: sales)
  end

  # --- API ---

  def morning_total
    to_currency(morning_cents)
  end

  def afternoon_total
    to_currency(afternoon_cents)
  end

  def total
    to_currency(total_cents)
  end

  def count
    @preloaded_sales ? @preloaded_sales.count : base_scope.count
  end

  def empty?
    count.zero?
  end

  # Utile per la view 'show'
  def morning_sales
    return filter_sales_in_memory { |s| s.created_at < split_time } if @preloaded_sales
    base_scope.where("created_at < ?", split_time).order(:created_at)
  end

  def afternoon_sales
    return filter_sales_in_memory { |s| s.created_at >= split_time } if @preloaded_sales
    base_scope.where("created_at >= ?", split_time).order(:created_at)
  end

  # --- LOGICA DI AGGREGAZIONE ---

  def morning_cents
    @morning_cents ||= base_scope.to_a.select { |s| s.created_at.in_time_zone.hour < SPLIT_HOUR }.sum(&:amount_cents)
  end

  def afternoon_cents
    @afternoon_cents ||= base_scope.to_a.select { |s| s.created_at.in_time_zone.hour >= SPLIT_HOUR }.sum(&:amount_cents)
  end

  def total_cents
    morning_cents + afternoon_cents
  end

  private

    def base_scope
      Sale.kept.where(sold_on: @date, payment_method: :cash)
    end

    def split_time
      @split_time ||= @date.in_time_zone.change(hour: SPLIT_HOUR, min: 0, sec: 0)
    end

    def to_currency(cents)
      return 0.0 unless cents
      cents / 100.0
    end

    # Helper per ordinare i risultati in memoria quando usiamo l'array
    def filter_sales_in_memory(&block)
      @preloaded_sales.select(&block).sort_by(&:created_at)
    end
end
