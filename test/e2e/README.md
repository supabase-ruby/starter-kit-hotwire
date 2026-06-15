# End-to-end tests

This directory holds the end-to-end (E2E) test suite. The tests drive a
real headless Chrome via Capybara + Selenium against an in-process Puma
server, and talk to a **live local Supabase stack** (Auth + Postgres)
booted by [`bin/e2e`](../../bin/e2e). No mocks, no stubs — the same wire
calls that production makes.

For prerequisites, how to run the suite, how to skip it, and
troubleshooting, see the [End-to-end tests](../../README.md#end-to-end-tests)
section of the root README. This document is the **author's guide**:
what's here, how the pieces fit, and how to add a new test.

## Layout

```
test/e2e/
├── README.md                                # this file
├── e2e_test_case.rb                         # E2ETestCase base class + helpers
├── smoke_test.rb                            # registration → dashboard
├── sign_up_flow_test.rb                     # sign-up happy + negative paths
├── sign_in_flow_test.rb                     # sign-in happy + negative paths
├── sign_out_flow_test.rb                    # sign-out + cookie clear
├── session_persistence_flow_test.rb         # multi-request session + JWT claim
├── session_expiry_flow_test.rb              # expired-session redirect + flash
├── rls_unauthorized_reads_flow_test.rb      # cross-user read RLS
└── rls_unauthorized_writes_flow_test.rb     # cross-user update/delete RLS
```

The `SupabaseReset` helper (and its unit tests) lives in
[`test/support/`](../support/supabase_reset.rb) — it's shared by E2E and
controller tests.

## Base class: `E2ETestCase`

Every E2E test inherits from `E2ETestCase` (defined in
[`e2e_test_case.rb`](e2e_test_case.rb)):

```ruby
require_relative "e2e_test_case"

class MyFlowTest < E2ETestCase
  test "…" do
    # …
  end
end
```

What it gives you out of the box:

- `driven_by :selenium, using: :headless_chrome` — Capybara is wired to a
  real WebDriver, so `page.driver.browser.manage.all_cookies` works,
  `execute_script` runs real JS, and assertions auto-wait for DOM
  updates.
- A `setup` hook that calls `SupabaseReset.clean!` — every test starts
  against an **empty `auth.users` table**, plus any AR tables registered
  via `SupabaseReset.tables=`.
- `screen_size: [1400, 1400]` — matches the existing
  `ApplicationSystemTestCase`, large enough that the sidebar / user menu
  layout doesn't collapse into the mobile breakpoint.

### Helpers

| Helper                              | Purpose                                                                                              |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `sign_up_as(email:, password:)`     | Walks `/registration/new`, fills email + password, submits. Caches `current_session_user`.           |
| `sign_in_as(email:, password:)`     | Walks `/session/new`, fills email + password, submits. Caches `current_session_user`.                |
| `current_session_user`              | Returns a `SignedInUser(email:)` for whichever helper last ran, or `nil`.                            |

**Important convention:** both helpers cache `@current_session_user`
unconditionally on submit — they're for **happy-path** tests. On
negative paths (wrong password, weak password, validation failures),
drive the form directly with `visit` + `fill_in` + `click_button` so the
cache doesn't lie about a sign-in that never happened. See
`sign_in_flow_test.rb#submit_sign_in` for the canonical pattern.

## `SupabaseReset` — between-test cleanup

[`SupabaseReset.clean!`](../support/supabase_reset.rb) is the
between-test reset hook. It:

1. Pages through `Supabase::Auth::AdminApi#list_users` (authenticated
   with the service-role key) and deletes every user.
2. `DELETE`s any ActiveRecord tables registered via
   `SupabaseReset.tables=` (host SQLite, not Supabase Postgres).

RLS-governed Postgres tables are emptied **transitively** by the
auth-user delete, as long as the table's `user_id` column is declared
with `references auth.users(id) on delete cascade`. Keep that cascade on
every per-user app table, or add a separate cleanup hook.

You usually don't call `SupabaseReset.clean!` yourself — `E2ETestCase`'s
`setup` block does it for you. But the admin client it builds is also
useful for seeding:

```ruby
SupabaseReset.admin.create_user(
  email: email,
  password: password,
  email_confirm: true   # sign-in-ready; without this the user is pending confirmation
)
```

## Adding a new test

1. **Pick a file name.** One flow per file, named `<flow>_flow_test.rb`
   (matches the existing convention). Keep file scope tight — each test
   class concentrates on one feature surface (sign-in, RLS, etc.).

2. **Inherit and require:**

   ```ruby
   # frozen_string_literal: true

   require_relative "e2e_test_case"
   require_relative "../support/supabase_reset"

   class MyFeatureFlowTest < E2ETestCase
     test "…" do
       # …
     end
   end
   ```

3. **Seed the state you need.** For a sign-in-ready user, use
   `SupabaseReset.admin.create_user(... email_confirm: true)`. For
   RLS-governed app data, POST through `Supabase::Postgrest::Client`
   with the user's JWT (see
   [`rls_unauthorized_reads_flow_test.rb`](rls_unauthorized_reads_flow_test.rb)
   for the pattern).

4. **Drive the UI** with `visit`, `fill_in`, `click_button`,
   `assert_selector`, etc. Pin selectors to `data-test="..."`
   attributes — they're stable refactor targets, unlike text or CSS
   classes. See the existing tests for the conventions:

   ```ruby
   assert_selector "[data-test='dashboard']"
   assert_selector "form[data-test='login-form']"
   assert_selector "[data-test='login-error']", text: "Invalid email or password"
   ```

5. **Assert what you actually want to verify.** Don't lean on
   `current_session_user` (it's cached from the helper, not read from
   the server). When you need to check the cookie or the database, read
   them directly:

   - **Cookies:** `page.driver.browser.manage.all_cookies.map { |c| c[:name] }`
   - **Database (RLS-bypassing):** `Supabase::Postgrest::Client` with
     `apikey` = `SUPABASE_SERVICE_ROLE_KEY`, `Authorization: Bearer
     <SERVICE_ROLE_KEY>`. See
     [`rls_unauthorized_writes_flow_test.rb`](rls_unauthorized_writes_flow_test.rb)
     for the pattern.

## Patterns and escape hatches

Several common situations recur — these are the patterns the existing
tests already use, so prefer them over inventing new ones.

### Bypassing HTML5 form validation

Server-side validation tests on `<input type="email" required>` are
unreachable through the browser unless you disable native validation.
Set `novalidate` via JS before submitting:

```ruby
page.execute_script(
  "document.querySelector('form[data-test=\"register-form\"]').setAttribute('novalidate', '')"
)
```

See `sign_up_flow_test.rb` for working examples.

### Driving non-GET requests (PATCH / DELETE)

Capybara's headless Chrome driver can't directly issue PATCH/DELETE.
Build a hidden form via `execute_script`, populate it with the page's
CSRF token + a `_method` field, then submit:

```ruby
page.execute_script(<<~JS)
  const f = document.createElement('form');
  f.method = 'post';
  f.action = '#{note_path(id)}';
  f.innerHTML = `
    <input name="authenticity_token" value="${document.querySelector('meta[name=csrf-token]').content}">
    <input name="_method" value="patch">
    <input name="note[content]" value="bob-was-here">
  `;
  document.body.appendChild(f);
  f.submit();
JS
```

See `rls_unauthorized_writes_flow_test.rb` for the full pattern.

### Reading the encrypted `sb-session` cookie

The session cookie is encrypted with Rails' `EncryptedKeyRotatingCookieJar`
(aes-256-gcm, `NullSerializer` at the encryptor, `SerializerWithFallback[:json]`
outside, `purpose: "cookie.sb-session"` on the metadata envelope). See
`session_persistence_flow_test.rb` and `session_expiry_flow_test.rb` for
the verified round-trip recipe — including the JWT-claim decode for
`sub`.

### Interacting with the user menu

The user-menu dropdown's `data-controller="dropdown"` has no matching
Stimulus controller — the menu stays `display: none`. Selenium can't
click hidden elements, so reveal it first:

```ruby
page.execute_script(
  "document.querySelector('[data-dropdown-target=\"menu\"]').classList.remove('hidden')"
)
```

See `sign_out_flow_test.rb` for the working example.

## Running a single test

`bin/e2e` accepts any command after the bootstrap; you can target a
single file or a single test name:

```bash
bin/e2e bin/rails test test/e2e/smoke_test.rb
bin/e2e bin/rails test test/e2e/sign_in_flow_test.rb -n /valid credentials/
```

The Supabase stack is reused if it's already up — only the first run
pays the boot cost.

## What does NOT belong here

- **Unit tests** for helpers / supporting code → `test/support/`.
- **Controller tests** that don't need the real Supabase stack →
  `test/controllers/`.
- **System tests** that use mock or in-memory adapters →
  `test/system/`. The line is "does this need a live Auth + DB?". If
  yes, it's an E2E test.
