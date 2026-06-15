# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"

# End-to-end coverage of the email + password sign-in flow against the real
# local Supabase stack. Covers the happy path (pre-seeded user → dashboard +
# session cookie set) and both negative paths (wrong password, unknown email)
# — both must surface the SAME generic error so the form leaks no signal
# about which accounts exist.
class SignInFlowTest < E2ETestCase
  INVALID_CREDENTIALS_MESSAGE = "Invalid email or password"
  SESSION_COOKIE_NAME = "sb-session"

  test "valid credentials land on the dashboard with a session cookie" do
    email    = "signin+#{SecureRandom.hex(4)}@example.test"
    password = "signin-test-password-#{SecureRandom.hex(4)}"
    seed_user(email: email, password: password)

    sign_in_as(email: email, password: password)

    assert_current_path root_path
    assert_selector "[data-test='dashboard']"
    assert_equal email, current_session_user.email

    # The dashboard's sidebar UserMenu falls back to the email when no
    # display name is set, so a freshly seeded user's email is visible
    # on the page itself — not just inside the dropdown.
    assert_text email

    assert_includes browser_cookie_names, SESSION_COOKIE_NAME,
                    "Expected Supabase session cookie to be set after sign-in"
  end

  test "wrong password shows the generic error and stays on the sign-in page" do
    email    = "wrongpw+#{SecureRandom.hex(4)}@example.test"
    password = "signin-test-password-#{SecureRandom.hex(4)}"
    seed_user(email: email, password: password)

    submit_sign_in(email: email, password: "totally-not-the-password")

    assert_selector "[data-test='login-error']", text: INVALID_CREDENTIALS_MESSAGE
    assert_selector "form[data-test='login-form']"
    assert_no_selector "[data-test='dashboard']"
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME
  end

  test "unknown email shows the same generic error (no user enumeration)" do
    # No seeding — this email does not exist in Supabase Auth.
    submit_sign_in(email: "ghost+#{SecureRandom.hex(4)}@example.test",
                   password: "signin-test-password-#{SecureRandom.hex(4)}")

    assert_selector "[data-test='login-error']", text: INVALID_CREDENTIALS_MESSAGE
    assert_selector "form[data-test='login-form']"
    assert_no_selector "[data-test='dashboard']"
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME
  end

  private

  # Pre-seeds a user via the admin API with `email_confirm: true` so they can
  # sign in immediately without going through the email-confirmation flow.
  def seed_user(email:, password:)
    SupabaseReset.admin.create_user(
      email: email,
      password: password,
      email_confirm: true
    )
  end

  # Submits the sign-in form directly, bypassing the E2ETestCase `sign_in_as`
  # helper which unconditionally caches `@current_session_user` — that cache
  # would lie on negative-path tests where authentication is expected to fail.
  def submit_sign_in(email:, password:)
    visit new_session_path
    assert_selector "form[data-test='login-form']"

    fill_in "email", with: email
    fill_in "password", with: password
    click_button "Log in"
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end
end
