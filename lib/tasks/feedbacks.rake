namespace :feedbacks do
  desc "Segnalazioni degli ultimi 30 giorni, dello staff e della manutenzione (kamal feedbacks)"
  task recent: :environment do
    feedbacks = Feedback.where(created_at: 30.days.ago..).order(created_at: :desc).includes(:user)
    puts "Nessuna segnalazione negli ultimi 30 giorni." if feedbacks.none?

    feedbacks.each do |feedback|
      puts "#{I18n.l(feedback.created_at, format: "%d/%m/%Y %H:%M")}  #{feedback.user&.username || "sistema"}  #{feedback.page_url || feedback.browser_info}"
      puts "  #{feedback.message}"
    end
  end
end
