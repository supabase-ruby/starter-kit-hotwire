# frozen_string_literal: true

require "test_helper"

class OauthControllerTest < ActionDispatch::IntegrationTest
  test "GET /oauth/:provider/authorize redirects to the Supabase-issued provider URL" do
    SupabaseAuthStubs.stub(
      :supabase_sign_in_with_oauth,
      Supabase::Rails::Result.success("https://github.com/login/oauth/authorize?stub=1")
    )

    get oauth_authorize_path(provider: "github")

    assert_redirected_to "https://github.com/login/oauth/authorize?stub=1"
    call = SupabaseAuthStubs.calls[:supabase_sign_in_with_oauth].first
    assert_equal "github", call[:provider]
  end

  test "GET /oauth/callback exchanges the code, starts a session, and redirects to dashboard" do
    fake_session = Object.new
    SupabaseAuthStubs.stub(:supabase_exchange_code_for_session, Supabase::Rails::Result.success(fake_session))
    SupabaseAuthStubs.stub(:start_new_session_user) { |_session| nil }

    get oauth_callback_path, params: { code: "gh-auth-code", state: "verifier-state" }

    assert_redirected_to root_url
    assert_equal I18n.t("supabase.rails.oauth.connected"), flash[:notice]

    call = SupabaseAuthStubs.calls[:supabase_exchange_code_for_session].first
    assert_equal "gh-auth-code", call[:code]
    assert_equal "verifier-state", call[:state]
  end

  test "GET /oauth/callback with a missing PKCE verifier redirects to sign-in with an alert" do
    error = Supabase::Rails::AuthError.pkce_missing_verifier
    SupabaseAuthStubs.stub(:supabase_exchange_code_for_session, Supabase::Rails::Result.failure(error))

    get oauth_callback_path, params: { code: "gh-auth-code", state: "stale-state" }

    assert_redirected_to new_session_path
    assert_match(/PKCE verifier missing/, flash[:alert])
  end
end
