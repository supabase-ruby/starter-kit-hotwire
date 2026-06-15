# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"

# End-to-end coverage of the sign-out flow against the real local Supabase
# stack. Drives the UI: signs in a pre-seeded user, opens the user menu,
# clicks "Sign out", and asserts the three guarantees that matter for shared
# devices — public landing page after sign-out, encrypted session cookie
# cleared, and the dashboard URL no longer serves the signed-in view.
class SignOutFlowTest < E2ETestCase
  SESSION_COOKIE_NAME = "sb-session"

  test "signed-in user can sign out and lose access to the dashboard" do
    email    = "signout+#{SecureRandom.hex(4)}@example.test"
    password = "signout-test-password-#{SecureRandom.hex(4)}"
    seed_user(email: email, password: password)

    sign_in_as(email: email, password: password)
    assert_selector "[data-test='dashboard']"
    assert_includes browser_cookie_names, SESSION_COOKIE_NAME,
                    "Sanity: sign-in should have set the session cookie before we exercise sign-out"

    click_sign_out

    # AC 1: redirected to the public landing page (welcome).
    assert_current_path welcome_path
    assert_selector "[data-test='welcome-page']"

    # AC 2: encrypted session cookie cleared. The cookie name comes from
    # `SessionStore::DEFAULT_COOKIE_NAME` in supabase-rails; `terminate_session`
    # in the gem's Authentication concern deletes it before we redirect.
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME,
                        "Expected Supabase session cookie to be cleared after sign-out"

    # AC 3: the dashboard URL is no longer authenticated — `HomeController`
    # routes `/dashboard` through `require_authentication`, which redirects
    # signed-out visitors to `new_session_path`.
    visit dashboard_path
    assert_current_path new_session_path
    assert_selector "form[data-test='login-form']"
  end

  private

  # Pre-seeds a sign-in-ready user via the admin API (`email_confirm: true`
  # bypasses the email-confirmation step so the password form authenticates
  # immediately). Same shape as `SignInFlowTest#seed_user`.
  def seed_user(email:, password:)
    SupabaseReset.admin.create_user(
      email: email,
      password: password,
      email_confirm: true
    )
  end

  # Reveals the user-menu dropdown (its Stimulus controller doesn't exist
  # in this app yet — `data-controller="dropdown"` is a no-op, so the menu
  # stays `display: none`) and clicks the sign-out button inside it. The
  # button is a `button_to`-rendered form that DELETEs `/session`.
  def click_sign_out
    assert_selector "[data-test='user-menu-button']"
    page.execute_script(<<~JS)
      document.querySelector('[data-dropdown-target="menu"]').classList.remove('hidden');
    JS
    click_button "Sign out"
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end
end
