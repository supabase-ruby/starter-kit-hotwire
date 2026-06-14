# frozen_string_literal: true

require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "signing in via the Hotwire sign-in form" do
    fake_session = Object.new
    SupabaseAuthStubs.stub(:authenticate_with_supabase, fake_session)

    visit new_session_path

    assert_selector "form[data-test='login-form']"
    assert_selector "[data-test='oauth-github-button']"

    fill_in "email", with: "alice@example.test"
    fill_in "password", with: "secret-pass"
    click_button "Log in"

    assert_current_path root_path
    call = SupabaseAuthStubs.calls[:authenticate_with_supabase].first
    assert_equal "alice@example.test", call[:email]
    assert_equal "secret-pass", call[:password]
  end
end
