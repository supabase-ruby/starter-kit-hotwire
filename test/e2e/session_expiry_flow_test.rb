# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"
require "active_support/message_encryptor"
require "active_support/messages/serializer_with_fallback"
require "cgi"

# End-to-end coverage of session-expiry handling. Signs in for real, surgically
# rewrites the encrypted `sb-session` cookie so the persisted `expires_at` is
# in the past *and* the `refresh_token` is bogus (so the gem's inline refresh
# attempt fails fast with a 4xx instead of accidentally succeeding), then hits
# a protected page and expects a clean redirect to the sign-in form with a
# "Your session has expired" flash. Also asserts `log/e2e.log` recorded no new
# 500-level errors over the expiry-handling request — the whole point of this
# story is that an expired session is handled, not crashed.
class SessionExpiryFlowTest < E2ETestCase
  SESSION_COOKIE_NAME = "sb-session"
  SESSION_EXPIRED_MESSAGE = Authentication::SESSION_EXPIRED_FLASH

  test "expired session redirects to sign-in with a flash and no 500s" do
    email    = "expiry+#{SecureRandom.hex(4)}@example.test"
    password = "expiry-test-password-#{SecureRandom.hex(4)}"
    seed_user(email: email, password: password)

    sign_in_as(email: email, password: password)
    assert_selector "[data-test='dashboard']",
                    "Sanity: sign-in must reach the dashboard before we expire the session"
    assert_includes browser_cookie_names, SESSION_COOKIE_NAME,
                    "Sanity: session cookie must be set before we mutate it"

    expire_session_cookie!
    log_offset = e2e_log_size

    visit dashboard_path

    assert_current_path new_session_path,
                        "Expected expired-session request to redirect to the sign-in page"
    assert_selector "form[data-test='login-form']"
    assert_selector "[data-test='login-error']", text: SESSION_EXPIRED_MESSAGE
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME,
                        "Expected the invalid session cookie to be cleared by the middleware"

    assert_no_new_server_errors(log_offset)
  end

  private

  def seed_user(email:, password:)
    SupabaseReset.admin.create_user(
      email: email,
      password: password,
      email_confirm: true
    )
  end

  # Decrypts the live `sb-session` cookie, past-dates `expires_at` and
  # invalidates `refresh_token`, then re-encrypts using the same key + purpose
  # + serializer pipeline ActionDispatch's `EncryptedKeyRotatingCookieJar`
  # uses internally. Writes the result back via WebDriver so the browser
  # sends it on the next request — same shape Rails wrote, just with a
  # poisoned payload.
  def expire_session_cookie!
    cookie = browser_session_cookie
    flunk("Expected #{SESSION_COOKIE_NAME} cookie before expiring it") if cookie.nil?

    ciphertext = CGI.unescape(cookie[:value])
    payload = cookie_serializer.load(
      cookie_encryptor.decrypt_and_verify(ciphertext, purpose: cookie_purpose)
    )
    flunk("Could not decrypt session cookie; check key + purpose setup") if payload.nil?

    payload["expires_at"]    = Time.now.to_i - 3600
    payload["refresh_token"] = "invalid-refresh-token-#{SecureRandom.hex(8)}"

    new_ciphertext = cookie_encryptor.encrypt_and_sign(
      cookie_serializer.dump(payload),
      purpose: cookie_purpose
    )

    page.driver.browser.manage.delete_cookie(SESSION_COOKIE_NAME)
    page.driver.browser.manage.add_cookie(
      name: SESSION_COOKIE_NAME,
      value: CGI.escape(new_ciphertext),
      path: "/"
    )
  end

  def browser_session_cookie
    page.driver.browser.manage.all_cookies.find { |c| c[:name] == SESSION_COOKIE_NAME }
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end

  # ActionDispatch wraps a NullSerializer-backed MessageEncryptor whose plain
  # text *is* the value the cookies_serializer dumped — we mirror that exact
  # split here so encrypt → decrypt round-trips with Rails' real cookie jar.
  def cookie_encryptor
    @cookie_encryptor ||= ActiveSupport::MessageEncryptor.new(
      Rails.application.key_generator.generate_key(
        Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt,
        ActiveSupport::MessageEncryptor.key_len
      ),
      cipher: "aes-256-gcm",
      serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )
  end

  def cookie_serializer
    @cookie_serializer ||= ActiveSupport::Messages::SerializerWithFallback[:json]
  end

  def cookie_purpose
    "cookie.#{SESSION_COOKIE_NAME}"
  end

  def e2e_log_path
    Rails.root.join("log", "e2e.log")
  end

  def e2e_log_size
    File.exist?(e2e_log_path) ? File.size(e2e_log_path) : 0
  end

  # Reads bytes written to `log/e2e.log` since `offset` and flunks if any of
  # them look like a 500-level response. Scoped to bytes appended during the
  # expiry-handling request so unrelated noise from earlier in the test (the
  # sign-up, sign-in, etc.) is intentionally ignored.
  def assert_no_new_server_errors(offset)
    return unless File.exist?(e2e_log_path)

    new_content = File.open(e2e_log_path, "rb") do |f|
      f.seek(offset)
      f.read.to_s
    end

    bad_lines = new_content.lines.grep(/Completed 5\d\d|Internal Server Error/)
    assert bad_lines.empty?,
           "Expected no 500-level entries in log/e2e.log during expiry handling, found:\n" \
           "#{bad_lines.join}"
  end
end
