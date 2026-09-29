require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "content security policy is strict and nonced" do
    get new_session_path

    csp = response.headers["Content-Security-Policy"]
    assert_match "default-src 'self'", csp
    assert_match "object-src 'none'", csp
    assert_match "frame-ancestors 'none'", csp
    assert_match(/script-src 'self' 'nonce-[^']+'/, csp)
    assert_no_match(/script-src[^;]*unsafe-inline/, csp)
  end

  test "importmap inline script carries the nonce" do
    get new_session_path

    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    assert_select "script[type=importmap][nonce='#{nonce}']"
  end

  test "permissions policy disables device apis" do
    get new_session_path

    policy = response.headers["Permissions-Policy"] || response.headers["Feature-Policy"]
    assert_match(/camera 'none'|camera=\(\)/, policy)
  end

  test "session cookie is httponly" do
    post session_path, params: { username: "staff", password: "password" }
    assert_match(/httponly/i, response.headers["Set-Cookie"].to_s)
  end
end
