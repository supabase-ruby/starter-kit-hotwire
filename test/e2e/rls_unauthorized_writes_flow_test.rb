# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"
require "active_support/message_encryptor"
require "active_support/messages/serializer_with_fallback"
require "cgi"
require "supabase/postgrest"

# End-to-end coverage that Postgres RLS prevents one signed-in user from
# UPDATING or DELETING another's `public.notes` rows. The companion read
# test (`rls_unauthorized_reads_flow_test.rb`) fences the `select` policy
# from above (Rails view) and from below (PostgREST). This test does the
# same for the `update` and `delete` policies — Bob targets Alice's note
# id directly through the Rails `notes#update` / `notes#destroy` controller
# actions and we assert (a) the UI surfaces the "Note not found" alert
# (PostgREST returns zero affected rows because the policy USING clause
# hides Alice's row from Bob's session), and (b) a service-role read
# bypassing RLS shows Alice's row is still present and unchanged.
class RlsUnauthorizedWritesFlowTest < E2ETestCase
  SESSION_COOKIE_NAME = "sb-session"
  NOTES_TABLE = "notes"

  test "RLS blocks unauthorized update + delete via the Rails controller and the underlying row is unchanged" do
    alice = build_user_credentials(prefix: "alice")
    bob   = build_user_credentials(prefix: "bob")
    seed_user(alice)
    seed_user(bob)

    # --- Alice signs in and inserts a note (via her own JWT so the insert
    # policy is exercised). Capture the row id so Bob can target it. ---
    sign_in_as(email: alice[:email], password: alice[:password])
    alice_token = read_access_token_from_cookie!

    original_content = "alice-secret-#{SecureRandom.hex(6)}"
    alice_note = postgrest_with(alice_token)
      .from(NOTES_TABLE)
      .insert(content: original_content)
      .execute
      .data
      .first
    alice_note_id = alice_note.fetch("id")
    assert alice_note_id.to_s.match?(/\A[0-9a-f-]{36}\z/i),
           "Sanity: PostgREST insert must return Alice's new note id"

    # --- Switch to Bob. ---
    sign_out_via_user_menu
    sign_in_as(email: bob[:email], password: bob[:password])

    # AC 1 + 2 — Bob fires an UPDATE against Alice's note ID through the
    # Rails controller. RLS USING hides Alice's row from Bob's session, so
    # PostgREST reports zero affected rows; the controller surfaces that
    # as the "Note not found" alert on `/notes`.
    visit notes_path
    assert_current_path notes_path
    assert_selector "[data-test='notes-empty']"

    forged_content = "bob-was-here-#{SecureRandom.hex(4)}"
    submit_form_to(
      note_path(alice_note_id),
      method: :patch,
      fields: { "note[content]" => forged_content }
    )

    assert_current_path notes_path
    assert_selector "[data-test='notes-flash-alert']", text: NotesController::NOT_FOUND_MESSAGE
    assert_no_selector "[data-test='note-item']",
                      "Bob still must not see Alice's note in his own list view"

    # AC 3 (after UPDATE) — service-role read bypasses RLS and confirms
    # Alice's row is unchanged in Postgres (same content, same owner).
    actual = service_role_postgrest
      .from(NOTES_TABLE)
      .select("id,content,user_id")
      .eq("id", alice_note_id)
      .execute
      .data
    assert_equal 1, actual.length,
                 "Alice's row must still exist after Bob's UPDATE attempt"
    assert_equal original_content, actual.first["content"],
                 "Alice's row content must be unchanged after Bob's UPDATE attempt"

    # AC 1 + 2 — same shape for DELETE.
    submit_form_to(note_path(alice_note_id), method: :delete)

    assert_current_path notes_path
    assert_selector "[data-test='notes-flash-alert']", text: NotesController::NOT_FOUND_MESSAGE
    assert_no_selector "[data-test='note-item']"

    # AC 3 (after DELETE) — Alice's row STILL exists with original content.
    actual = service_role_postgrest
      .from(NOTES_TABLE)
      .select("id,content,user_id")
      .eq("id", alice_note_id)
      .execute
      .data
    assert_equal 1, actual.length,
                 "Alice's row must still exist after Bob's DELETE attempt"
    assert_equal original_content, actual.first["content"],
                 "Alice's row content must remain its original value after Bob's DELETE attempt"
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

  # Injects a hidden form into the live page (carrying the page's own CSRF
  # token, so Rails accepts the POST), then submits it. Rails routes the
  # POST to the named verb via the `_method` field. Selenium follows the
  # redirect like a real browser, and Capybara's auto-waiting handles
  # next-page assertions on the line after.
  def submit_form_to(path, method:, fields: {})
    csrf = page.evaluate_script(
      "document.querySelector('meta[name=\"csrf-token\"]').content"
    )
    body = { "authenticity_token" => csrf, "_method" => method.to_s }.merge(fields)
    input_html = body.map { |k, v|
      "<input type=\"hidden\" name=\"#{CGI.escapeHTML(k)}\" " \
        "value=\"#{CGI.escapeHTML(v.to_s)}\">"
    }.join

    page.execute_script(<<~JS)
      const form = document.createElement('form');
      form.action = #{path.to_json};
      form.method = 'post';
      form.style.display = 'none';
      form.innerHTML = #{input_html.to_json};
      document.body.appendChild(form);
      form.submit();
    JS
  end

  # Reveals the user-menu dropdown (its Stimulus controller is a no-op in
  # this starter, so the menu stays display:none until we drop the class)
  # and clicks the sign-out button, matching the pattern from
  # `SignOutFlowTest` and `RlsUnauthorizedReadsFlowTest`.
  def sign_out_via_user_menu
    page.execute_script(<<~JS)
      document.querySelector('[data-dropdown-target="menu"]').classList.remove('hidden');
    JS
    click_button "Sign out"
    assert_not_includes browser_cookie_names, SESSION_COOKIE_NAME,
                        "Sanity: sign-out should clear the session cookie before the next sign-in"
  end

  # Reads + decrypts the live `sb-session` cookie and returns the persisted
  # `access_token`. Mirrors the recipe in the read RLS test — NullSerializer
  # at the encryptor with `SerializerWithFallback[:json]` wrapping the
  # payload, plus a `cookie.<name>` purpose.
  def read_access_token_from_cookie!
    cookie = page.driver.browser.manage.all_cookies
      .find { |c| c[:name] == SESSION_COOKIE_NAME }
    flunk("Expected #{SESSION_COOKIE_NAME} cookie to be set after sign-in") if cookie.nil?

    ciphertext = CGI.unescape(cookie[:value])
    payload = cookie_serializer.load(
      cookie_encryptor.decrypt_and_verify(ciphertext, purpose: cookie_purpose)
    )
    flunk("Could not decrypt session cookie; check key + purpose setup") if payload.nil?

    token = payload["access_token"]
    if token.to_s.empty?
      flunk("Decrypted session cookie did not contain an access_token; keys: #{payload.keys.inspect}")
    end
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

  # PostgREST client bound to a specific user's JWT — `apikey` is the
  # publishable (anon) key (PostgREST project-level auth), `Authorization`
  # is what populates `auth.uid()` inside RLS policies.
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

  # Service-role PostgREST client — the service_role JWT bypasses RLS by
  # design, so this reads the live database state from outside Rails
  # without RLS interference. Use this to verify "underlying row in
  # Supabase is unchanged" without trusting any layer above the DB.
  def service_role_postgrest
    @service_role_postgrest ||= Supabase::Postgrest::Client.new(
      base_url: "#{ENV.fetch('SUPABASE_URL')}/rest/v1",
      headers: {
        "apikey" => ENV.fetch("SUPABASE_SERVICE_ROLE_KEY"),
        "Authorization" => "Bearer #{ENV.fetch('SUPABASE_SERVICE_ROLE_KEY')}"
      },
      timeout: 5
    )
  end

  def browser_cookie_names
    page.driver.browser.manage.all_cookies.map { |c| c[:name] }
  end
end
