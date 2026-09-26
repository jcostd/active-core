class PaymentReceiptPdf < ApplicationPdf
  # --- COSTANTI DI IMPAGINAZIONE ---
  # MODIFICA SPAZI: Allargo la destra, stringo la sinistra per non sovrapporre
  HEADER_RIGHT_WIDTH   = 240  # Era 180 (Più spazio per il numero lungo)
  HEADER_RIGHT_X       = 300  # Era 350 (Spostato a sx per farci stare i 240pt)
  HEADER_LEFT_WIDTH    = 290  # Era 360 (Ridotto per non toccare la destra)

  RECIPIENT_BOX_WIDTH  = 400
  TABLE_DESC_COL_WIDTH = 380

  def initialize(sale)
    super()
    @sale = sale
    @member = sale.member
    # nome congelato alla vendita: la ricevuta non cambia se il prodotto viene rinominato
    @product_name = @sale.product_name_snapshot.presence || @sale.product&.name || "Servizio Palestra"
    @gym_profile = GymProfile.current

    header_section
    recipient_section
    body_section
    footer_legal_section
  end

  def header_section
    # --- DESTRA (Dati Ricevuta) ---
    float do
      bounding_box([ HEADER_RIGHT_X, cursor ], width: HEADER_RIGHT_WIDTH) do
        # MODIFICA LOGICA:
        # Se c'è il codice ricevuta -> "RICEVUTA N. 123/2025"
        # Se NON c'è -> Scriviamo "RIEPILOGO" (o nulla) ma NON "Ricevuta N."
        if @sale.respond_to?(:receipt_code) && @sale.receipt_code.present?
          text "RICEVUTA N. #{@sale.receipt_code}", size: FONT_SIZE_L, style: :bold, align: :right, color: COLOR_ACCENT
        else
          # Titolo alternativo per quando non è fiscale
          text "RIEPILOGO", size: FONT_SIZE_L, style: :bold, align: :right, color: COLOR_SECONDARY
        end

        text "Data: #{I18n.l(@sale.sold_on)}", size: FONT_SIZE_M, align: :right
        move_down GAP_XS
        text "Pagamento: #{SalesHelper::PAYMENT_METHODS.dig(@sale.payment_method, :label)}", size: FONT_SIZE_S, align: :right
      end
    end

    # --- SINISTRA (Dati Palestra) ---
    span(HEADER_LEFT_WIDTH, position: :left) do
      text @gym_profile.name, size: FONT_SIZE_XL, style: :bold, color: COLOR_PRIMARY
      text "Associazione Sportiva Dilettantistica", size: FONT_SIZE_S, color: COLOR_SECONDARY

      move_down GAP_S

      if @gym_profile.full_address.present?
        text @gym_profile.full_address, size: FONT_SIZE_S, color: COLOR_PRIMARY
        move_down 2
      end

      contacts = []
      contacts << "Tel: #{@gym_profile.phone}" if @gym_profile.phone.present?
      contacts << "Email: #{@gym_profile.email}" if @gym_profile.email.present?

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

    prefix =
      case @sale.receipt_sequence
      when "associative"
        "Quota Associativa"
      when "institutional"
        "Quota Istituzionale"
      else
        "Contributo"
      end

    description = "#{prefix}: #{@product_name}"

    # Se è un abbonamento, mostriamo le date
    if @sale.subscription
       description += "\nValidità: #{I18n.l(@sale.subscription.start_date)} - #{I18n.l(@sale.subscription.end_date)}"
    end

    data = [
      [ "DESCRIZIONE", "IMPORTO" ],
      [ description, format_currency(@sale.amount) ],
      [ "TOTALE", format_currency(@sale.amount) ]
    ]

    table(data, width: bounds.width) do
      # Intestazione
      row(0).font_style = :bold
      row(0).size = FONT_SIZE_XS
      row(0).text_color = COLOR_SECONDARY
      row(0).background_color = COLOR_BG_HEADER
      row(0).borders = [ :bottom ]
      row(0).border_color = COLOR_LINE

      # Corpo
      cells.padding = [ GAP_S, GAP_XS ]
      cells.borders = [ :bottom ]
      cells.border_width = 0.5
      cells.border_color = COLOR_LINE

      # Piè di pagina (Totale)
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
