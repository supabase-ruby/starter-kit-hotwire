# frozen_string_literal: true

require "test_helper"
require "capybara/rails"
require "selenium-webdriver"
require_relative "../support/supabase_reset"

# Base class for end-to-end tests that drive the real Rails app via headless
# Chrome and talk to a live local Supabase stack started by `bin/e2e`.
#
# Inheriting from `ActionDispatch::SystemTestCase` gives us Capybara wired up
# against an in-process Puma server, transactional fixtures disabled, and
# screenshot-on-failure. The `setup` hook calls `SupabaseReset.clean!` so each
# example starts from an empty Auth table; the helpers below remove the
# boilerplate of navigating the sign-up / sign-in forms by hand.
#
# Usage:
#
#   class CheckoutFlowTest < E2ETestCase
#     test "user can purchase a thing" do
#       sign_up_as(email: "shopper@example.test", password: "supersecret123")
#       assert_selector "[data-test='dashboard']"
#       assert_equal "shopper@example.test", current_session_user.email
#     end
#   end
#
class E2ETestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Lightweight representation of the user that the most recent
  # `sign_up_as` / `sign_in_as` helper authenticated. Mirrors the subset
  # of `Supabase::Rails::User` fields that E2E assertions typically need;
  # the value is server-thread state we can't read back, so we cache what
  # the helper itself put on the wire.
  SignedInUser = Data.define(:email)

  setup do
    SupabaseReset.clean!
    @current_session_user = nil
  end

  # Walks the registration form end-to-end. Asserts the form rendered so a
  # routing regression fails fast instead of looking like an auth error.
  def sign_up_as(email:, password:)
    visit new_registration_path
    assert_selector "form[data-test='register-form']"

    fill_in "email", with: email
    fill_in "password", with: password
    click_button "Create account"

    @current_session_user = SignedInUser.new(email: email)
  end

  # Walks the password sign-in form end-to-end.
  def sign_in_as(email:, password:)
    visit new_session_path
    assert_selector "form[data-test='login-form']"

    fill_in "email", with: email
    fill_in "password", with: password
    click_button "Log in"

    @current_session_user = SignedInUser.new(email: email)
  end

  # The user the most recent `sign_up_as` / `sign_in_as` authenticated, or
  # `nil` if neither has run in this test. Read it after asserting the
  # sign-in succeeded so the value reflects the actual session.
  def current_session_user
    @current_session_user
  end
end
