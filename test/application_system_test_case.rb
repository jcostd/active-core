require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # SYSTEM_BROWSER=headless_firefox bin/rails test:system dove Chrome non c'è
  driven_by :selenium, using: ENV.fetch("SYSTEM_BROWSER", "headless_chrome").to_sym, screen_size: [ 1400, 1400 ]

  def sign_in(username)
    visit new_session_path
    fill_in "username", with: username
    fill_in "password", with: "password"
    click_on "Entra"
    assert_no_current_path new_session_path
  end
end
