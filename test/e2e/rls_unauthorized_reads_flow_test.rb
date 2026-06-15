# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"
require "active_support/message_encryptor"
require "active_support/messages/serializer_with_fallback"
require "cgi"
require "supabase/postgrest"

# End-to-end coverage that Postgres RLS prevents one signed-in user from
# reading another's `public.notes` rows — via the Rails `notes#index` view
# AND via a direct PostgREST query with each user's JWT (the AC 4
# "sanity-check the policy itself" assertion). The migration under
# `supabase/migrations/` enables RLS on `public.notes` with a `select`
# policy keyed on `auth.uid() = user_id`; this test fences that policy
# from above (Rails) and from below (raw Supabase REST) so a regression
# in either layer trips a clear failure.
class RlsUnauthorizedReadsFlowTest < E2ETestCase
  SESSION_COOKIE_NAME = "sb-session"
  NOTES_TABLE = "notes"

  test "RLS blocks unauthorized reads via the Rails list view and direct Supabase queries" do
    alice = build_user_credentials(prefix: "alice")
    bob   = build_user_credentials(prefix: "bob")
    seed_user(alice)
    seed_user(bob)

    # --- Alice signs in, inserts a note as herself (via her own JWT so the
    # insert policy is also exercised), and reads it back through both
    # surfaces. ---
    sign_in_as(email: alice[:email], password: alice[:password])
    alice_token = read_access_token_from_cookie!

    note_content = "alice-secret-#{SecureRandom.hex(6)}"
    alice_postgrest = postgrest_with(alice_token)
    insert_response = alice_postgrest.from(NOTES_TABLE).insert(content: note_content).execute
    assert_equal [ note_content ], insert_response.data.map { |r| r["content"] },
                 "Alice's own insert via PostgREST should succeed (RLS insert policy permits self-owned rows)"

    # AC 3 — signed in as Alice, the Rails list view shows the row.
    visit notes_path
    assert_current_path notes_path
    assert_selector "[data-test='notes-page']"
    assert_selector "[data-test='note-item']", text: note_content

    # AC 4 (Alice leg) — same query against Supabase directly with her JWT.
    alice_rows = alice_postgrest.from(NOTES_TABLE).select("content").execute.data
    assert_equal [ note_content ], alice_rows.map { |r| r["content"] },
                 "Direct Supabase REST with Alice's JWT must return her own note"

    # --- Switch to Bob: clear Alice's session, sign Bob in, repeat the
    # observations. ---
    sign_out_via_user_menu
    sign_in_as(email: bob[:email], password: bob[:password])
    bob_token = read_access_token_from_cookie!
    refute_equal alice_token, bob_token,
                 "Sanity: Bob's access token must differ from Alice's, otherwise the RLS test below proves nothing"

    # AC 2 — signed in as Bob, the Rails list view shows zero notes (Alice's
    # row is filtered out by the `select` policy at the database layer).
    visit notes_path
    assert_current_path notes_path
    assert_selector "[data-test='notes-page']"
    assert_no_selector "[data-test='note-item']",
                      "Bob must not see Alice's note through the Rails list view"
    assert_selector "[data-test='notes-empty']"

    # AC 4 (Bob leg) — same query against Supabase directly with his JWT
    # returns nothing, sanity-checking that the empty Rails view is the RLS
    # policy speaking and not, e.g., a stray controller-side filter masking
    # a policy regression.
    bob_postgrest = postgrest_with(bob_token)
    bob_rows = bob_postgrest.from(NOTES_TABLE).select("content").execute.data
    assert_empty bob_rows,
                 "Direct Supabase REST with Bob's JWT must return zero notes (RLS blocks reads of Alice's row)"
  end

  private

  def build_user_credentials(prefix:)
    {
      email: "#{prefix}+#{SecureRandom.hex(4)}@example.test",
      password: "rls-test-password-#{SecureRandom.hex(4)}"
    }
  end

  def seed_user(credentials)
    SupabaseReset.admin.create_user(
      email: credentials[:email],
      password: credentials[:password],
      email_confirm: true
    )
  end

  # Reveals the user-menu dropdown (its Stimulus controller is a no-op in
  # this starter, so the menu stays display:none until we drop the class)
  # and clicks the sign-out button, matching the pattern from
  # `SignOutFlowTest`.
  def sign_out_via_user_menu
    page.execute_script(<<~JS)
      document.querySelector('[data-dropdown-target="menu"]').classList.remove('hidden');
    JS
    click_button "Sign out"
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME,
                        "Sanity: sign-out should clear the session cookie before the next sign-in"
  end

  # Reads + decrypts the live `sb-session` cookie and returns the persisted
  # `access_token`. Mirrors the recipe in `SessionPersistenceFlowTest` /
  # `SessionExpiryFlowTest` — ActionDispatch's encrypted cookie jar uses
  # NullSerializer at the encryptor with `SerializerWithFallback[:json]`
  # wrapping the payload, plus a `cookie.<name>` purpose. Returns the raw
  # JWT string a PostgREST client can drop straight into an Authorization
  # header.
  def read_access_token_from_cookie!
    cookie = page.driver.browser.manage.all_cookies.find { |c| c[:name] == SESSION_COOKIE_NAME }
    flunk("Expected #{SESSION_COOKIE_NAME} cookie to be set after sign-in") if cookie.nil?

    ciphertext = CGI.unescape(cookie[:value])
    payload = cookie_serializer.load(
      cookie_encryptor.decrypt_and_verify(ciphertext, purpose: cookie_purpose)
    )
    flunk("Could not decrypt session cookie; check key + purpose setup") if payload.nil?

    token = payload["access_token"]
    flunk("Decrypted session cookie did not contain an access_token; keys: #{payload.keys.inspect}") if token.to_s.empty?
    token
  end

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

  # Builds a fresh PostgREST client whose Authorization header carries the
  # given user JWT. `apikey` is still the anon publishable key (PostgREST
  # requires it on every request), but the JWT is what drives RLS — the
  # database sees `auth.uid() = <token.sub>`.
  def postgrest_with(access_token)
    Supabase::Postgrest::Client.new(
      base_url: "#{ENV.fetch('SUPABASE_URL')}/rest/v1",
      headers: {
        "apikey" => ENV.fetch("SUPABASE_ANON_KEY"),
        "Authorization" => "Bearer #{access_token}"
      },
      timeout: 5
    )
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end
end
