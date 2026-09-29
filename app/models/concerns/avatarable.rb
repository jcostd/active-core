module Avatarable
  extend ActiveSupport::Concern

  def initials
    "#{first_name.to_s.first}#{last_name.to_s.first}".upcase
  end

  def avatar_color_style
    hue = (id.to_i * 137) % 360
    "background-color: hsl(#{hue}, 70%, 85%); color: hsl(#{hue}, 80%, 30%); border-color: hsl(#{hue}, 60%, 80%);"
  end
end
