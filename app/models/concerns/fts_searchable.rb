module FtsSearchable
  extend ActiveSupport::Concern

  class_methods do
    def search_text(query)
      return all if query.blank?

      fts_query = format_for_fts(query)
      return all if fts_query.blank?

      fts_table = "#{table_name}_fts"

      joins("JOIN #{fts_table} ON #{table_name}.id = #{fts_table}.rowid")
        .where("#{fts_table} MATCH ?", fts_query)
        .order("#{fts_table}.rank")
    end

    private

      def format_for_fts(query)
        clean = query.gsub(/[^\p{L}\p{N}\s]/, " ").squish
        return nil if clean.blank?

        # "san polo" -> "san* polo*" (nota lo spazio nel join qui sotto!)
        clean.split.map { |word| "#{word}*" }.join(" ")
      end
  end
end
