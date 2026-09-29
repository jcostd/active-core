class PaymentReceiptPdf < ApplicationPdf
  # a destra c'è posto per un numero di ricevuta lungo, senza toccare l'intestazione a sinistra
  HEADER_RIGHT_WIDTH   = 240
  HEADER_RIGHT_X       = 300
  HEADER_LEFT_WIDTH    = 290

  RECIPIENT_BOX_WIDTH  = 400
  TABLE_DESC_COL_WIDTH = 380

  SEQUENCES = { "associative" => "Quota Associativa", "institutional" => "Quota Istituzionale" }.freeze

  def initialize(sale)
    super()
    @sale = sale
    @member = sale.member
    @gym_profile = GymProfile.current

    header_section
    recipient_section
    body_section
    footer_legal_section
  end

  def header_section
    float do
      bounding_box([ HEADER_RIGHT_X, cursor ], width: HEADER_RIGHT_WIDTH) do
        # solo i contanti hanno un numero di ricevuta; gli altri pagamenti un riepilogo
        if @sale.receipt_code
          text "RICEVUTA N. #{@sale.receipt_code}", size: FONT_SIZE_L, style: :bold, align: :right, color: COLOR_ACCENT
        else
          text "RIEPILOGO", size: FONT_SIZE_L, style: :bold, align: :right, color: COLOR_SECONDARY
        end

        text "Data: #{I18n.l(@sale.sold_on)}", size: FONT_SIZE_M, align: :right
        move_down GAP_XS
        text "Pagamento: #{SalesHelper::PAYMENT_METHODS.dig(@sale.payment_method, :label)}", size: FONT_SIZE_S, align: :right
      end
    end

    span(HEADER_LEFT_WIDTH, position: :left) do
      text @gym_profile.name, size: FONT_SIZE_XL, style: :bold, color: COLOR_PRIMARY
      text "Associazione Sportiva Dilettantistica", size: FONT_SIZE_S, color: COLOR_SECONDARY

      move_down GAP_S

      if @gym_profile.full_address.present?
        text @gym_profile.full_address, size: FONT_SIZE_S, color: COLOR_PRIMARY
        move_down 2
      end

      contacts = [ ("Tel: #{@gym_profile.phone}" if @gym_profile.phone.present?), ("Email: #{@gym_profile.email}" if @gym_profile.email.present?) ].compact
      if contacts.any?
        text contacts.join("  |  "), size: FONT_SIZE_S, color: COLOR_PRIMARY
        move_down 2
      end

      if @gym_profile.vat_number.present?
        text "C.F./P.IVA: #{@gym_profile.vat_number}", size: FONT_SIZE_S, style: :bold, color: COLOR_PRIMARY
      end
    end

    move_down GAP_M
    draw_divider
    move_down GAP_M
  end

  def recipient_section
    text "Rilasciata a:", size: FONT_SIZE_XS, color: COLOR_SECONDARY, style: :bold, transform: :uppercase

    bounding_box([ 0, cursor ], width: RECIPIENT_BOX_WIDTH) do
      text @member.full_name, size: FONT_SIZE_L, style: :bold
      move_down GAP_XS

      if @member.fiscal_code.present?
        text "C.F. #{@member.fiscal_code.upcase}", size: FONT_SIZE_M, style: :bold
      else
        text "C.F. Non disponibile", size: FONT_SIZE_M, style: :italic, color: COLOR_SECONDARY
      end
    end

    move_down GAP_M
  end

  def body_section
    text "CAUSALE VERSAMENTO", size: FONT_SIZE_XS, style: :bold, color: COLOR_SECONDARY
    move_down GAP_XS

    # nome congelato alla vendita: la ricevuta non cambia se il prodotto viene rinominato
    description = "#{SEQUENCES.fetch(@sale.receipt_sequence, "Contributo")}: #{@sale.product_name_snapshot}"
    description += "\nValidità: #{I18n.l(@sale.subscription.start_date)} - #{I18n.l(@sale.subscription.end_date)}" if @sale.subscription

    data = [
      [ "DESCRIZIONE", "IMPORTO" ],
      [ description, format_cents(@sale.amount_cents) ],
      [ "TOTALE", format_cents(@sale.amount_cents) ]
    ]

    table(data, width: bounds.width) do
      row(0).font_style = :bold
      row(0).size = FONT_SIZE_XS
      row(0).text_color = COLOR_SECONDARY
      row(0).background_color = COLOR_BG_HEADER
      row(0).borders = [ :bottom ]
      row(0).border_color = COLOR_LINE

      cells.padding = [ GAP_S, GAP_XS ]
      cells.borders = [ :bottom ]
      cells.border_width = 0.5
      cells.border_color = COLOR_LINE

      row(-1).font_style = :bold
      row(-1).size = FONT_SIZE_L
      row(-1).background_color = "FFFFFF"
      row(-1).borders = []
      row(-1).padding_top = GAP_M

      column(0).width = TABLE_DESC_COL_WIDTH
      column(1).align = :right
    end
  end

  def footer_legal_section
    footer_height = 60
    iban_text = @gym_profile.bank_iban.present? ? "IBAN: #{@gym_profile.bank_iban}\n" : ""

    bounding_box([ bounds.left, bounds.bottom + footer_height ], width: bounds.width, height: footer_height) do
      text "NOTE FISCALI", size: FONT_SIZE_XS, style: :bold, color: COLOR_PRIMARY
      move_down 3

      legal_text = "#{iban_text}Operazione effettuata in conformità all'art. 148 del T.U.I.R. e art. 4 del D.P.R. 633/72.\n" \
                   "Somma versata a titolo di quota associativa o corrispettivo specifico."

      text legal_text, size: FONT_SIZE_XS, color: COLOR_SECONDARY, align: :justify, leading: 1
    end
  end
end
