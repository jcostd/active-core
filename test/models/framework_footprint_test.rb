require "test_helper"

class FrameworkFootprintTest < ActiveSupport::TestCase
  test "unused frameworks are not loaded" do
    assert_not defined?(ActionText)
    assert_not defined?(ActionMailbox)
    assert_not defined?(ActiveStorage)
    assert_not defined?(ActionMailer)
  end
end
