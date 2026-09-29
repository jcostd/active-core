require "test_helper"
require "rake"

class RakeTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task.tasks.each(&:reenable)
  end

  def run_task(name) = capture_io { Rake::Task[name].invoke }.first

  test "fts rebuild is the maintenance one, by hand" do
    Member.connection.execute("DELETE FROM members_fts")

    assert_match "FTS ricostruito", run_task("fts:rebuild")
    assert_includes Member.search_text("Alice"), members(:alice)
  end

  test "recent feedbacks, from staff and system, newest first" do
    Feedback.create!(user: users(:staff), message: "Il bottone non va", page_url: "/sales/new", created_at: 2.days.ago)
    Feedback.create!(message: "Manutenzione del database, check: rotto", browser_info: "DatabaseMaintenance.check")
    Feedback.create!(user: users(:staff), message: "Vecchia", created_at: 40.days.ago)

    output = run_task("feedbacks:recent")
    assert_match(/sistema  DatabaseMaintenance.check\n  Manutenzione del database, check: rotto\n.*staff  \/sales\/new\n  Il bottone non va/m, output)
    assert_no_match "Vecchia", output
  end

  test "no recent feedbacks" do
    assert_match "Nessuna segnalazione", run_task("feedbacks:recent")
  end

  test "invalid fiscal codes are listed" do
    members(:bob).update_column(:fiscal_code, "VECCHIOCODICE000")

    output = run_task("members:invalid_fiscal_codes")
    assert_match "1 soci con codice fiscale non valido", output
    assert_match "VECCHIOCODICE000", output
    assert_no_match "Alice", output
  end

  test "all valid fiscal codes" do
    assert_match "Tutti i codici fiscali sono validi", run_task("members:invalid_fiscal_codes")
  end

  test "pending fiscal codes are listed apart" do
    Member.create!(first_name: "Ana", last_name: "Silva", birth_date: "1990-05-05", fiscal_code_pending: true)
    output = run_task("members:invalid_fiscal_codes")
    assert_match "1 soci con CF da completare", output
    assert_match "Ana Silva", output
  end
end
