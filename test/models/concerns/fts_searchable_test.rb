require "test_helper"

class FtsSearchableTest < ActiveSupport::TestCase
  test "prefix search on first and last name" do
    assert_includes Member.search_text("ali"), members(:alice)
    assert_includes Member.search_text("bian"), members(:bob)
  end

  test "multi word query matches all words" do
    assert_equal [ members(:alice) ], Member.search_text("alice allevi").to_a
    assert_empty Member.search_text("alice bianchi")
  end

  test "fiscal code search" do
    assert_equal [ members(:bob) ], Member.search_text("BNCBOB").to_a
  end

  test "search limited to some columns ignores the others" do
    name_only = %i[first_name last_name]

    assert_equal [ members(:bob) ], Member.search_text("bob bianchi", columns: name_only).to_a
    assert_empty Member.search_text("BNCBOB", columns: name_only)
    assert_empty Member.search_text("bob@example", columns: name_only)
    assert_empty Member.search_text("1990", columns: name_only)
  end

  test "column limited search still neutralises operators" do
    assert_nothing_raised { Member.search_text(%q{"alice" OR * NEAR( -}, columns: %i[first_name last_name]).to_a }
    assert_includes Member.search_text("ali", columns: %i[last_name first_name]), members(:alice)
  end

  test "punctuation and fts operators are neutralised" do
    assert_nothing_raised { Member.search_text(%q{"alice" OR * NEAR( -}).to_a }
    assert_equal Member.count, Member.search_text("!!!").count
  end

  test "operator words are searched as plain text" do
    members(:bob).update!(last_name: "Or")
    assert_includes Member.search_text("OR"), members(:bob)
    assert_nothing_raised { Member.search_text("NOT NEAR AND").to_a }
  end

  test "blank query returns everything" do
    assert_equal Member.count, Member.search_text("  ").count
  end

  test "index follows updates" do
    members(:bob).update!(last_name: "Verdoni")
    assert_includes Member.search_text("verdon"), members(:bob)
    assert_not_includes Member.search_text("bianchi"), members(:bob)
  end
end
