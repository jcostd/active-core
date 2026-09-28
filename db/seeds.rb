# utente fisso dell'iPad del kiosk (nei database esistenti lo crea la migrazione CreateKioskUser)
User.kiosk.first_or_create!(username: "kiosk", first_name: "Kiosk", last_name: "Accessi",
                            password: SecureRandom.base58(24))
