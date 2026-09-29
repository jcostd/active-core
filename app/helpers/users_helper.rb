module UsersHelper
  # classi scritte per intero perché Tailwind le trovi
  USER_ROLE_STYLES = {
    "staff" => { label: "Staff",          badge: "badge-neutral" },
    "admin" => { label: "Amministratore", badge: "badge-primary" },
    "kiosk" => { label: "Kiosk",          badge: "badge-accent" }
  }.freeze

  def user_role_label(user) = USER_ROLE_STYLES.fetch(user.role)[:label]

  def user_role_badge(user, size: "badge-sm")
    tag.span user_role_label(user), class: [ "badge font-bold uppercase text-[10px]", size, USER_ROLE_STYLES.fetch(user.role)[:badge] ]
  end

  def user_role_options
    User::ASSIGNABLE_ROLES.map { [ USER_ROLE_STYLES.fetch(it)[:label], it ] }
  end
end
