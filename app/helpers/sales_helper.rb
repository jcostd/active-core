module SalesHelper
  PAYMENT_METHODS = {
    "cash"          => { label: "Contanti",    icon: "payments",        color: "badge-success" },
    "credit_card"   => { label: "Carta / POS", icon: "credit_card",     color: "badge-info" },
    "bank_transfer" => { label: "Bonifico",    icon: "account_balance", color: "badge-warning" },
    "other"         => { label: "Altro",       icon: "receipt",         color: "badge-ghost" }
  }.freeze

  UNCATEGORIZED = "Quote e Varie".freeze

  # prodotti del POS raggruppati per disciplina (uno può stare in più gruppi); quote e varie in cima
  def grouped_product_options
    groups = Hash.new { |hash, name| hash[name] = [] }
    Product.kept.order(:name).includes(:disciplines).each do |product|
      names = product.disciplines.reject(&:discarded?).map(&:name).presence || [ UNCATEGORIZED ]
      names.each { groups[it] << [ product.name, product.id ] }
    end
    groups.sort_by { |name, _| [ name == UNCATEGORIZED ? 0 : 1, name ] }
  end

  # chi frequenta senza abbonamento: il POS si apre con socio e prodotto già scelti, date e prezzo li propone lui
  def sell_to_walk_in_link(member, product)
    link_to new_sale_path(sale: { member_id: member.id, product_id: product&.id }.compact),
            class: "btn btn-sm btn-primary max-w-56", data: { turbo_frame: "modal" }, title: "Vendi #{product&.name}".strip do
      safe_join([ icon("shopping_cart", classes: "size-4"), tag.span(product ? "Vendi #{product.name}" : "Vendi", class: "truncate") ])
    end
  end

  def payment_method_options
    PAYMENT_METHODS.map { |key, data| [ data[:label], key ] }
  end

  def payment_method(method) = PAYMENT_METHODS.fetch(method.to_s) { PAYMENT_METHODS["other"] }

  def payment_method_icon(method, classes: "size-6") = icon(payment_method(method)[:icon], classes:)

  def payment_method_badge(method)
    data = payment_method(method)
    tag.div class: [ "badge badge-sm badge-soft gap-1 text-[10px] uppercase font-bold tracking-wider", data[:color] ] do
      icon(data[:icon], classes: "size-3") + " #{data[:label]}"
    end
  end
end
