# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"
require "active_support/message_encryptor"
require "base64"
require "cgi"
require "json"

# End-to-end coverage of session persistence against the real local Supabase
# stack. Asserts that a signed-in user (1) can navigate between multiple
# authenticated pages without being prompted to sign in again, (2) keeps their
# session across a hard browser reload, and (3) carries a Supabase JWT whose
# `sub` claim matches the user's Supabase id — proving the encrypted session
# cookie is truly tied to the signed-in identity.
class SessionPersistenceFlowTest < E2ETestCase
  SESSION_COOKIE_NAME = "sb-session"

  test "session persists across protected pages, reload, and embeds the signed-in user's JWT" do
    email    = "session+#{SecureRandom.hex(4)}@example.test"
    password = "session-test-password-#{SecureRandom.hex(4)}"
    user_id  = seed_user(email: email, password: password)

    sign_in_as(email: email, password: password)
    assert_selector "[data-test='dashboard']"

    # AC 1: navigate to 3 protected pages; each should render its real view,
    # never the sign-in form. The dashboard + both settings pages are all
    # gated by `require_authentication` (settings via the gem default,
    # /dashboard via the conditional `allow_unauthenticated_access` in
    # HomeController).
    visit_authenticated_page(dashboard_path, "[data-test='dashboard']")
    visit_authenticated_page(settings_profile_path, "[data-test='settings-profile-page']")
    visit_authenticated_page(settings_appearance_path, "[data-test='settings-appearance-page']")

    # AC 2: hard browser reload should keep the session alive — Capybara's
    # `visit` may or may not round-trip cookies depending on the driver, so
    # use the underlying WebDriver navigate.refresh for a real reload.
    visit dashboard_path
    assert_includes browser_cookie_names, SESSION_COOKIE_NAME,
                    "Sanity: session cookie should be set before we reload"
    page.driver.browser.navigate.refresh

    assert_current_path dashboard_path
    assert_selector "[data-test='dashboard']"
    assert_no_selector "form[data-test='login-form']"
    assert_includes browser_cookie_names, SESSION_COOKIE_NAME,
                    "Session cookie should still be present after the browser reload"

    # AC 3: the JWT inside the encrypted cookie has `sub == user_id`. We
    # decrypt the cookie with the same key-generator setup ActionDispatch
    # uses (host secret_key_base + the standard salt), then read the JWT
    # payload without verifying the signature — verifying would require
    # Supabase's JWT secret, which is out of scope for this assertion.
    payload = decrypt_session_cookie
    access_token = payload.fetch("access_token") do
      flunk("Encrypted session cookie did not contain an access_token; keys: #{payload.keys.inspect}")
    end
    jwt_claims = decode_jwt_payload(access_token)

    assert_equal user_id, jwt_claims["sub"],
                 "Expected the JWT in the session cookie to be signed for user #{user_id}, " \
                 "got sub=#{jwt_claims['sub'].inspect}"
  end

  private

  # Pre-seeds a confirmed user via the admin API and returns their Supabase id
  # so the test can later assert the JWT's `sub` claim matches.
  def seed_user(email:, password:)
    response = SupabaseReset.admin.create_user(
      email: email,
      password: password,
      email_confirm: true
    )
    response.user.id
  end

  def visit_authenticated_page(path, view_selector)
    visit path
    assert_current_path path
    assert_selector view_selector
    assert_no_selector "form[data-test='login-form']",
                       "Unexpected sign-in form on #{path} — session may not have persisted"
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end

  # Reads the encrypted session cookie from the Selenium-driven browser and
  # decrypts it using the same MessageEncryptor configuration the Rails
  # encrypted cookie jar uses internally (key derived from secret_key_base
  # + the standard "authenticated encrypted cookie" salt, JSON serializer,
  # aes-256-gcm cipher). Returns the decrypted hash of session credentials.
  def decrypt_session_cookie
    cookie = page.driver.browser.manage.all_cookies.find { |c| c[:name] == SESSION_COOKIE_NAME }
    flunk("Expected #{SESSION_COOKIE_NAME} cookie to be set in the browser") if cookie.nil?

    # Browsers store the URL-encoded form sent in Set-Cookie; Rails' cookie
    # middleware URL-decodes before handing off to the encryptor, so we
    # mirror that here.
    ciphertext = CGI.unescape(cookie[:value])

    encryptor = ActiveSupport::MessageEncryptor.new(
      Rails.application.key_generator.generate_key(
        Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt,
        ActiveSupport::MessageEncryptor.key_len
      ),
      cipher: "aes-256-gcm",
      serializer: JSON
    )
    encryptor.decrypt_and_verify(ciphertext)
  end

  # Decodes the JWT payload segment without verifying the signature — we
  # only need to read the `sub` claim, and the signing key (Supabase's JWT
  # secret) is not exposed to the host app.
  def decode_jwt_payload(token)
    _header, payload_segment, _signature = token.split(".")
    flunk("Access token did not look like a JWT: #{token.inspect}") if payload_segment.nil?

    JSON.parse(Base64.urlsafe_decode64(pad_base64(payload_segment)))
  end

  def pad_base64(str)
    str + ("=" * ((4 - (str.length % 4)) % 4))
  end
end
