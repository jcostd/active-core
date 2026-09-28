# registri del mese (presenze, private): il mese in corso lo corregge chiunque, i mesi chiusi solo l'admin, quelli futuri nessuno
module MonthlyRegister
  extend ActiveSupport::Concern

  class_methods do
    def current_month = Date.current.beginning_of_month

    def editable_by?(user, date)
      month = date.to_date.beginning_of_month
      month == current_month || (user.admin? && month < current_month)
    end
  end
end
