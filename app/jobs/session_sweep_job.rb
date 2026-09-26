class SessionSweepJob < ApplicationJob
  queue_as :default

  def perform = Session.sweep
end
