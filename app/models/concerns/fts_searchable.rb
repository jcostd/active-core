module FtsSearchable
  extend ActiveSupport::Concern

  class_methods do
    # columns: limita la ricerca a quelle colonne dell'indice (es. solo il nome, dove il CF non deve servire)
    def search_text(query, columns: nil)
      return all if query.blank?

      fts_query = format_for_fts(query, columns)
      return all if fts_query.blank?

      fts_table = "#{table_name}_fts"

      joins("JOIN #{fts_table} ON #{table_name}.id = #{fts_table}.rowid")
        .where("#{fts_table} MATCH ?", fts_query)
        .order("#{fts_table}.rank")
    end

    private

      def format_for_fts(query, columns)
        clean = query.gsub(/[^\p{L}\p{N}\s]/, " ").squish
        return nil if clean.blank?

        # "san polo" -> "san"* "polo"*: le virgolette neutralizzano OR/AND/NOT/NEAR
        filter = "{#{columns.join(" ")}} : " if columns
        clean.split.map { %(#{filter}"#{it}"*) }.join(" ")
      end
  end
end
