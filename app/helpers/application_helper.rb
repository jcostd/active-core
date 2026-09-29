module ApplicationHelper
  # testo semplice per <title>: i titoli dei form contengono icone
  def page_title = CGI.unescapeHTML(strip_tags(content_for(:title).to_s)).squish.presence || "Active Core"
end
