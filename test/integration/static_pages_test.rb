require "test_helper"

class StaticPagesTest < ActiveSupport::TestCase
  PAGES = Dir[Rails.root.join("public/*.html")]

  test "error pages exist for the statuses Rails serves" do
    %w[400 404 406-unsupported-browser 422 500].each do |name|
      assert File.exist?(Rails.root.join("public/#{name}.html")), name
    end
  end

  test "error pages are in italian" do
    PAGES.each do |file|
      doc = Nokogiri::HTML5(File.read(file))
      text = doc.at("main").text

      assert_equal "it", doc.at("html")["lang"], file
      english = /\b(the|your|you|was|were|please|sorry|wrong|doesn't|owner|request|page)\b/i
      assert_no_match english, text, file
      assert_no_match english, doc.at("title").text, file
    end
  end
end
