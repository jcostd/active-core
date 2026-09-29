require "test_helper"

class SessionSweepJobTest < ActiveJob::TestCase
  test "deletes expired sessions" do
    session = users(:staff).sessions.create!
    travel Session::IDLE_TIMEOUT + 1.minute

    SessionSweepJob.perform_now

    assert_not Session.exists?(session.id)
  end

  test "is scheduled as recurring task in production" do
    tasks = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result)
    assert_equal "SessionSweepJob", tasks.dig("production", "sweep_expired_sessions", "class")
  end
end
