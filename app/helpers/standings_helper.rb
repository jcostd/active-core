module StandingsHelper
  # unica fonte per la posizione del socio nel mese; classi scritte per intero perché Tailwind le trovi
  STANDING_BADGES = { paid: "badge-success", due: "badge-warning", no_membership: "badge-error", not_enrolled: "badge-error" }.freeze

  STANDING_CARDS = {
    ok:      { card: "bg-base-100 border-base-200",     button: "btn-primary" },
    warning: { card: "bg-warning/5 border-warning/50", button: "btn-warning" },
    error:   { card: "bg-error/5 border-error/50",     button: "btn-error" }
  }.freeze

  def standing_card_style(standing) = STANDING_CARDS.fetch(standing.tone)

  def standing_badges(standing)
    badges = [ tag.span(standing.label, class: [ "badge badge-sm badge-soft uppercase text-[10px] font-bold", STANDING_BADGES.fetch(standing.key) ]) ]
    badges << tag.span("Cert. scaduto", class: "badge badge-sm badge-soft badge-error uppercase text-[10px] font-bold") if standing.certificate_missing?
    safe_join(badges, " ")
  end
end
