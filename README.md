# Supabase Rails Starter Kit

A Rails 8.1 starter kit with authentication backed by [Supabase Auth][supabase-auth]
via the [`supabase-rails`][supabase-rails] gem, ViewComponent-based UI,
Railsblocks components, and Tailwind v4.

**Repo:** <https://github.com/supabase-ruby/starter-kit-hotwire>
**License:** [MIT](./LICENSE)
**Gem reference:** <https://supabase-ruby.dev/reference/rails>

[supabase-auth]: https://supabase.com/docs/guides/auth
[supabase-rails]: https://rubygems.org/gems/supabase-rails

## Stack

- **Rails 8.1** — Hotwire (Turbo + Stimulus), Importmap, Propshaft, Solid
  Queue/Cache/Cable, SQLite.
- **Supabase Auth (`supabase-rails`)** — runs in `:web` mode. Ships sign-in,
  sign-up, password reset, OTP / magic-link, and GitHub OAuth. Uses a
  `Current.user` value object — no ActiveRecord `User` model, no shadow
  users table. See <https://supabase-ruby.dev/reference/rails>.
- **Railsblocks** — Tailwind component library installed via Importmap pins
  and CDN CSS/JS (see `config/importmap.rb` and `app/views/layouts/_head.html.erb`).
- **Tailwind v4** — built via `tailwindcss-rails`; source at
  `app/assets/tailwind/application.css`, output at `app/assets/builds/`.
- **ViewComponent** — UI primitives under `app/components/`.
- **lucide-rails** — Lucide icon set rendered via the `icon` helper.

## v1 scope

MFA (TOTP / backup codes), passkeys / WebAuthn, sudo mode, and identity
verification are **intentionally out of scope for v1** and are planned for
v2. The corresponding gems (`webauthn`, `rotp`, `rqrcode`, `bcrypt`) are not
in the Gemfile, the matching views and components are not ported, and the
settings sidebar does not link to a securities section.

## Prerequisites

- **Ruby 3.3+** (see `.ruby-version`)
- **Bundler** (`gem install bundler`)
- **SQLite 3.8.0+** (`sqlite3` CLI on PATH)
- **A Supabase project** — sign up at <https://supabase.com> and create a
  project to get the URL and keys below.
- **Node.js is NOT required** — JavaScript is served via Importmap.

## Quickstart

```bash
git clone https://github.com/supabase-ruby/starter-kit-hotwire.git
cd starter-kit-hotwire
cp .env.example .env   # then fill in the Supabase values (see below)
bin/setup              # installs gems, prepares the database, starts bin/dev
bin/dev                # if you passed --skip-server to bin/setup
```

Then open <http://localhost:3000>.

`bin/setup` is idempotent — re-run it any time. Pass `--skip-server` to
skip auto-launching the dev server (useful in CI or headless contexts), or
`--reset` to drop and recreate the database.

## Configuration

All configuration is via environment variables — see `.env.example` for the
full list with inline comments. The required values are:

| Variable                     | Where to find it                                                                                                                                                |
| ---                          | ---                                                                                                                                                             |
| `SUPABASE_URL`               | Supabase dashboard → Project Settings → API → Project URL                                                                                                       |
| `SUPABASE_ANON_KEY`          | Supabase dashboard → Project Settings → API → `anon` `public` key                                                                                               |
| `SUPABASE_SERVICE_ROLE_KEY`  | Supabase dashboard → Project Settings → API → `service_role` `secret` key. Server-only; never expose to browsers. Used for admin calls (e.g. account deletion). |
| `GITHUB_OAUTH_CLIENT_ID`     | GitHub → Settings → Developer settings → OAuth Apps (see below)                                                                                                 |
| `GITHUB_OAUTH_CLIENT_SECRET` | Same; generated when you register the OAuth app                                                                                                                 |

The GitHub OAuth credentials are documentation-only — they are read by
Supabase, not by Rails. They live in `.env.example` to make sharing values
across environments and onboarding new contributors easier.

## Development server

```bash
bin/dev
```

Runs `bin/rails server` (port 3000) and `bin/rails tailwindcss:watch` via
`Procfile.dev`. The app is at <http://localhost:3000>.

Useful in-app paths:

- `/` — home / dashboard shell.
- `/session/new` — sign in (email + password, OTP, or GitHub).
- `/registration/new` — sign up.
- `/settings/profile` — profile (display name).
- `/settings/appearance` — theme switcher (cookie-backed).
- `/letter_opener` — view emails sent in development.

## Sign in with GitHub

The sign-in and sign-up screens expose a single "Continue with GitHub" button.
GitHub OAuth is the only third-party provider wired in this starter; setting it
up takes two steps — registering a GitHub OAuth app, then pasting its
credentials into the Supabase dashboard.

### 1. Register a GitHub OAuth app

1. Sign in to GitHub and open **Settings → Developer settings → OAuth Apps**
   (or visit <https://github.com/settings/developers>).
2. Click **New OAuth App** and fill in:
   - **Application name** — anything; e.g. `My App (dev)`.
   - **Homepage URL** — `http://localhost:3000` for local development.
   - **Authorization callback URL** — the Supabase callback URL for your
     project. You can copy the exact value from the Supabase dashboard at
     **Authentication → Providers → GitHub** (it looks like
     `https://<project-ref>.supabase.co/auth/v1/callback`). Supabase, not
     Rails, is the OAuth redirect target — Supabase then hands the session
     back to this app at `/oauth/callback`.
3. Click **Register application**, then **Generate a new client secret**.
4. Copy the **Client ID** and the freshly generated **Client Secret**. Stash
   them in your local `.env` as `GITHUB_OAUTH_CLIENT_ID` and
   `GITHUB_OAUTH_CLIENT_SECRET`.

### 2. Add the credentials to the Supabase dashboard

1. Open your project at <https://supabase.com/dashboard> and navigate to
   **Authentication → Providers → GitHub**.
2. Toggle **Enable Sign in with GitHub**.
3. Paste the **Client ID** and **Client Secret** from the previous step.
4. Click **Save**.

That's it — the "Continue with GitHub" button on `/session/new` and
`/registration/new` is now live. On success, the gem's `OauthController`
exchanges the authorization code for a session and redirects the user to the
dashboard (`/`) or to the last-visited protected page they were trying to
reach before sign-in.

## Tests

```bash
bin/ci                  # runs the full lint + security + test suite
```

`bin/ci` runs (in order):

1. `bin/setup --skip-server` — installs gems, prepares the database.
2. `bin/rubocop` — Ruby style check.
3. `bin/brakeman` — Rails security scanner.
4. `bin/bundler-audit` — gem dependency vulnerability audit.
5. `bin/rails test` — Minitest suite.
6. `bin/rails test:system` — Capybara + headless Chrome system tests.

Any step that fails aborts the run with a non-zero exit code. To run a step
in isolation, just invoke the underlying command directly.

## End-to-end tests

`bin/e2e` boots a local Supabase stack via the Supabase CLI (`supabase start`,
which uses Docker under the hood) and exports its URL and keys into the
environment so the Rails test process can talk to a real backend instead of
mocks.

### Prerequisites

- **Docker** running locally — install [Docker Desktop](https://docs.docker.com/get-docker/).
- **Supabase CLI** on PATH — install via `brew install supabase/tap/supabase`
  or follow the [official docs](https://supabase.com/docs/guides/local-development/cli/getting-started).

### Running

```bash
bin/e2e                       # boot/reuse the stack, then exit (bootstrap only)
bin/e2e bin/rails test        # boot/reuse, then run the given command against it
```

The script is idempotent — if the stack is already running it reuses it
instead of restarting. First boot pulls Docker images and can take a few
minutes; subsequent runs are fast.

On success it exports:

- `SUPABASE_URL` — local API URL (e.g. `http://127.0.0.1:54321`)
- `SUPABASE_ANON_KEY` — local anon key
- `SUPABASE_SERVICE_ROLE_KEY` — local service-role key

Override the boot budget (default 120s) with `E2E_SUPABASE_TIMEOUT=240 bin/e2e`.

### Troubleshooting

- **"Supabase CLI not found"** — install via the link above and re-open your shell.
- **"Docker is not running"** — start Docker Desktop and wait for the whale icon to stop animating.
- **Port conflicts on 54321/54322** — another Supabase stack is already up; run
  `supabase stop` first or point your other project elsewhere.
- **Stack didn't come up in time** — bump `E2E_SUPABASE_TIMEOUT`, or check
  Docker's CPU/memory allocation in Docker Desktop → Settings → Resources.

## Icons

Icons are rendered via the [lucide-rails](https://github.com/Rails-Designer/lucide-rails)
gem, wrapped by the `icon` helper in `ApplicationHelper`.

```erb
<%= icon "check", class: "size-4 text-green-500" %>
<%= icon "chevron-down" %>
<%= icon "key", class: "size-5" %>
```

Browse the full Lucide set at <https://lucide.dev/icons/>.

## Verifying a release

Before tagging a release, run this smoke flow against a real Supabase project
to confirm end-to-end behavior. `bin/ci` alone is not enough — it does not
exercise the live Supabase API, email delivery, or the GitHub OAuth round-trip.

### Prerequisites

- A Supabase project you can throw test users into (a dedicated `staging` or
  `smoke` project is ideal — these flows create accounts that should not pollute
  production data).
- Email confirmations enabled at **Authentication → Sign In / Up → Email** in
  the Supabase dashboard.
- A GitHub OAuth app registered against this Supabase project — see
  [Sign in with GitHub](#sign-in-with-github).
- An inbox you can read for the test email address (Supabase delivers
  confirmation, password-reset, and magic-link mails through its own SMTP
  unless you have configured a custom provider).

### Setup

On a fresh clone:

```bash
git clone https://github.com/supabase-ruby/starter-kit-hotwire.git
cd starter-kit-hotwire
cp .env.example .env   # fill in the real Supabase + GitHub values
bin/setup --skip-server
bin/dev
```

- [ ] `bin/setup` finishes without errors (gems installed, database prepared).
- [ ] `bin/dev` prints `Listening on http://127.0.0.1:3000` and the page at
      <http://localhost:3000> renders the dashboard shell.

### 1. Sign-up → email confirmation → sign-in

- [ ] Open `/registration/new`, submit a fresh email + password (≥ 12 chars).
- [ ] The app redirects to `/session/new` with a "Check your email to confirm"
      notice.
- [ ] The confirmation email arrives in the test inbox; click the link.
- [ ] Supabase redirects back to the app, authenticated. `/` shows the
      authenticated dashboard chrome (sidebar + user menu).
- [ ] Sign out from the user menu, then sign in at `/session/new` with the
      same credentials. You land back on `/`.

### 2. Password reset

- [ ] Sign out. From `/session/new`, click "Forgot password?".
- [ ] Submit the test email at `/passwords/new`. A neutral confirmation flash
      renders (no enumeration leak).
- [ ] The reset email arrives; click the link. It opens
      `/passwords/:token/edit`.
- [ ] Submit a new password (≥ 12 chars). The app redirects to `/session/new`
      with an "Updated" notice.
- [ ] Sign in with the new password — you reach `/`.

### 3. GitHub OAuth

- [ ] Sign out. From `/session/new`, click **Continue with GitHub**.
- [ ] You are redirected to Supabase, which forwards you to GitHub. Authorize
      the app if prompted.
- [ ] GitHub bounces back through Supabase to `/oauth/callback`, and the app
      finally lands you on `/` authenticated. The user menu shows the
      GitHub-linked account.

### 4. OTP / magic-link

- [ ] Sign out. Open `/otp/new`, submit the test email.
- [ ] The OTP / magic-link email arrives. Either click the link, or copy the
      6-digit code and submit it at `/otp/verify?email=…`.
- [ ] The app redirects to `/` authenticated.

### 5. Profile update persists

- [ ] While signed in, open `/settings/profile`.
- [ ] Change the **Name** field, click **Save**. A "Profile updated." flash
      renders.
- [ ] Sign out, then sign in again with the same email + password.
- [ ] Open `/settings/profile` — the new display name is still there. Confirm
      in the Supabase dashboard at **Authentication → Users** that the user's
      `raw_user_meta_data.display_name` matches.

### Tear-down

- [ ] Delete the test users from the Supabase dashboard
      (**Authentication → Users → … → Delete user**) so the next release smoke
      starts clean.

If every checkbox above is ticked, the release is shippable.
