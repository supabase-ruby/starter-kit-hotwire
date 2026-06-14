# Supabase Rails Starter

A Rails 8.1 app pre-wired to authenticate against [Supabase Auth][supabase-auth]
via the [`supabase-rails`][supabase-rails] gem. Ships with Hotwire-style auth
views, Tailwind v4, and a placeholder dashboard.

[supabase-auth]: https://supabase.com/docs/guides/auth
[supabase-rails]: https://rubygems.org/gems/supabase-rails

## Getting started

```sh
bundle install
cp .env.example .env  # then fill in the Supabase values (see below)
bin/rails tailwindcss:build
bin/dev
```

The app boots on `http://localhost:3000`. Visiting `/` renders the dashboard
shell; sign-in lives at `/session/new` and sign-up at `/registration/new`.

## Configuration

All configuration is via environment variables — see `.env.example` for the
full list with inline comments. The two values you must set are:

- `SUPABASE_URL` — your project URL from the Supabase dashboard
  (Project Settings → API).
- `SUPABASE_ANON_KEY` — the public anon key from the same screen.

`SUPABASE_SERVICE_ROLE_KEY` is required for admin-side calls (e.g. account
deletion) and should never be exposed to browsers.

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
   `GITHUB_OAUTH_CLIENT_SECRET` (these env vars are documentation-only — the
   credentials are read by Supabase, not by Rails).

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

## Quality checks

```sh
bin/rubocop
bin/brakeman
bin/rails test
```
