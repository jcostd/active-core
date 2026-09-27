class ApplicationPdf < Prawn::Document
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TranslationHelper

  # --- PALETTE COLORI & COSTANTI (Invariate) ---
  COLOR_PRIMARY       = "333333"
  COLOR_SECONDARY     = "777777"
  COLOR_ACCENT        = "000000"
  COLOR_LINE          = "DDDDDD"
  COLOR_BG_HEADER     = "F4F4F4"

  FONT_SIZE_XS = 7
  FONT_SIZE_S  = 9
  FONT_SIZE_M  = 10
  FONT_SIZE_L  = 12
  FONT_SIZE_XL = 16

  GAP_XS = 5
  GAP_S  = 10
  GAP_M  = 20
  GAP_L  = 30

  def initialize(options = {})
    default_options = {
      page_size: "A4",
      margin: [ 40, 40, 40, 40 ],
      info: { Creator: "ActiveCore", Producer: "Prawn" }
    }
    super(default_options.merge(options))
    @view = ActionController::Base.new.view_context
    setup_fonts
  end

  FONTS_DIR = Rails.root.join("vendor/fonts")

  # ttf al posto dei font integrati: questi coprono solo Windows-1252 (niente Ș, Ł, ...)
  def setup_fonts
    font_families.update("LiberationSans" => {
      normal:      FONTS_DIR.join("LiberationSans-Regular.ttf").to_s,
      bold:        FONTS_DIR.join("LiberationSans-Bold.ttf").to_s,
      italic:      FONTS_DIR.join("LiberationSans-Italic.ttf").to_s,
      bold_italic: FONTS_DIR.join("LiberationSans-BoldItalic.ttf").to_s
    })
    font "LiberationSans"
    default_leading 3
  end

  def format_currency(amount)
    val = amount.is_a?(Integer) ? amount / 100.0 : amount
    @view.number_to_currency(val, locale: :it)
  end

  def draw_divider
    stroke do
      stroke_color COLOR_LINE
      horizontal_rule
      stroke_color COLOR_PRIMARY
    end
  end
end
