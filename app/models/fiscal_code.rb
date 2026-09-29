# codice fiscale italiano: struttura (con omocodia) e carattere di controllo
class FiscalCode
  OMOCODIA = "[0-9LMNPQRSTUV]"
  FORMAT = /\A[A-Z]{6}#{OMOCODIA}{2}[ABCDEHLMPRST]#{OMOCODIA}{2}[A-Z]#{OMOCODIA}{3}[A-Z]\z/

  ODD = {
    "0" => 1, "1" => 0, "2" => 5, "3" => 7, "4" => 9, "5" => 13, "6" => 15, "7" => 17, "8" => 19, "9" => 21,
    "A" => 1, "B" => 0, "C" => 5, "D" => 7, "E" => 9, "F" => 13, "G" => 15, "H" => 17, "I" => 19, "J" => 21,
    "K" => 2, "L" => 4, "M" => 18, "N" => 20, "O" => 11, "P" => 3, "Q" => 6, "R" => 8, "S" => 12, "T" => 14,
    "U" => 16, "V" => 10, "W" => 22, "X" => 25, "Y" => 24, "Z" => 23
  }.freeze

  def self.valid?(code) = new(code).valid?

  def initialize(code)
    @code = code.to_s.strip.upcase
  end

  def valid?
    FORMAT.match?(@code) && @code[15] == check_char
  end

  # posizioni dispari (1ª, 3ª, ...) con la tabella ODD, pari con il valore diretto
  def check_char
    sum = @code[0, 15].chars.each_with_index.sum do |char, index|
      index.even? ? ODD.fetch(char, 0) : (char.match?(/\d/) ? char.to_i : char.ord - 65)
    end
    (65 + sum % 26).chr
  end
end
