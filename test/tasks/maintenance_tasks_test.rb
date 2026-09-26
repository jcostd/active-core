require "test_helper"
require "rake"

class MaintenanceTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task.tasks.each(&:reenable)
  end

  def run_task(name) = capture_io { Rake::Task[name].invoke }.first

  test "sanitize_themes resets unknown themes to corporate" do
    users(:staff).update_column(:preferences, { "theme" => "neon" })
    users(:admin).update_column(:preferences, { "theme" => "dark" })

    output = run_task("maintenance:sanitize_themes")

    assert_equal "corporate", users(:staff).reload.preferences["theme"]
    assert_equal "dark", users(:admin).reload.preferences["theme"]
    assert_match "1 profili aggiornati", output
  end

  test "sanitize_themes with nothing to fix" do
    assert_match "Tutto pulito", run_task("maintenance:sanitize_themes")
  end

  test "fts rebuild restores a broken index" do
    Member.connection.execute("DELETE FROM members_fts")
    assert_empty Member.search_text("Alice")

    run_task("fts:rebuild")
    assert_includes Member.search_text("Alice"), members(:alice)
  end

  test "release v1 runs both steps" do
    output = run_task("release:v1")
    assert_match "FTS ricostruito", output
    assert_match "Rilascio V1 completato", output
  end
end
