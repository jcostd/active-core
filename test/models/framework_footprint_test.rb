require "test_helper"

class FrameworkFootprintTest < ActiveSupport::TestCase
  test "unused frameworks are not loaded" do
    assert_not defined?(ActionText)
    assert_not defined?(ActionMailbox)
  end

  test "frameworks kept for future use are loaded" do
    assert defined?(ActiveStorage)
    assert defined?(ActionMailer)
  end
end
