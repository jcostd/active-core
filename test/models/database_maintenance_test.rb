require "test_helper"
require "fugit"

class DatabaseMaintenanceTest < ActiveSupport::TestCase
  test "optimize runs on every database" do
    assert_nothing_raised { DatabaseMaintenance.optimize }
  end

  test "rebuild_search repairs a member search index out of step" do
    Member.connection.execute("DELETE FROM members_fts")
    assert_empty Member.search_text("Alice")

    DatabaseMaintenance.rebuild_search
    assert_includes Member.search_text("Alice"), members(:alice)
  end

  test "check passes on a sound database and names what is broken" do
    assert_nothing_raised { DatabaseMaintenance.check }

    Attendance.connection.disable_referential_integrity do
      Attendance.insert!({ member_id: 0, discipline_id: disciplines(:yoga).id, marked_by_id: users(:kiosk).id, month: Date.current.beginning_of_month })
    end

    assert_difference -> { Feedback.count } do
      error = assert_raises(DatabaseMaintenance::Problem) { DatabaseMaintenance.check }
      assert_match "1 righe di attendances puntano a record che non esistono", error.message
    end

    feedback = Feedback.last
    assert_nil feedback.user
    assert_equal "DatabaseMaintenance.check", feedback.browser_info
    assert_match "Manutenzione del database, check: primary: 1 righe di attendances", feedback.message
  end

  test "a backup that does not restore leaves a report for the developer" do
    original = Litestream.method(:verify!)
    Litestream.define_singleton_method(:verify!) { |*, **| raise Litestream::VerificationFailure, "Verification failed" }

    assert_raises(Litestream::VerificationFailure) { DatabaseMaintenance.verify_backup }
    assert_equal "Manutenzione del database, verify_backup: Verification failed", Feedback.last.message
  ensure
    Litestream.define_singleton_method(:verify!, original)
  end

  test "nothing is reported when all is well" do
    assert_no_difference -> { Feedback.count } do
      DatabaseMaintenance.optimize
      DatabaseMaintenance.rebuild_search
      DatabaseMaintenance.check
    end
  end

  test "the backup is verified on the primary database" do
    original, verified = Litestream.method(:verify!), nil
    Litestream.define_singleton_method(:verify!) { |path, **| verified = path }

    DatabaseMaintenance.verify_backup
    assert_equal ActiveRecord::Base.connection_db_config.database, verified
  ensure
    Litestream.define_singleton_method(:verify!, original)
  end

  test "vacuum never touches the primary database" do
    assert_empty DatabaseMaintenance.vacuum_support_databases, "nei test cache e coda non hanno un database a parte"
  end

  test "recurring tasks point to real code and valid schedules" do
    tasks = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true).fetch("production")

    tasks.each do |name, task|
      assert Fugit.parse_cron(task["schedule"]) || Fugit.parse_nat(task["schedule"]), "#{name}: orario non valido"
      if task["command"]
        receiver, method = task["command"].split(".", 2)
        assert receiver.constantize.respond_to?(method[/\A\w+/]), "#{name}: #{task["command"]} non esiste"
      else
        assert task["class"].safe_constantize, "#{name}: manca #{task["class"]}"
      end
    end
  end
end
