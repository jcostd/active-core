# maiuscole senza stravolgere ciò che è scritto con intenzione (D'Amico, McDonald, MMA):
# si toccano solo le parti tutte minuscole, o tutte maiuscole per persone e luoghi
module ProperCase
  extend self

  SEPARATORS = %r{([\s'’\-/])}
  ROMAN = /\A(?=[ivx])x{0,3}(ix|iv|v?i{0,3})\z/i

  # "d'AMICO" -> "D'Amico"
  def person(text)
    convert(text) { |part| uniform?(part) ? part.capitalize : part }
  end

  # "via xx settembre 12/a" -> "Via XX Settembre 12/A"
  def place(text)
    convert(text) { |part| roman?(part) ? part.upcase : uniform?(part) ? part.capitalize : part }
  end

  # "kick-boxing ii livello" -> "Kick-Boxing II Livello"; "MMA" e "CrossFit" restano
  def title(text)
    convert(text) { |part| roman?(part) ? part.upcase : part == part.downcase ? part.capitalize : part }
  end

  private
    def convert(text, &)
      text.to_s.squish.split(SEPARATORS).map(&).join.presence
    end

    def uniform?(part)
      part == part.downcase || part == part.upcase
    end

    def roman?(part)
      ROMAN.match?(part)
    end
end
