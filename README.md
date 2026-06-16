# Supabase Rails Starter Kit — Hotwire

A Rails 8.1 starter kit with authentication backed by
[Supabase Auth](https://supabase.com/docs/guides/auth) via the
[`supabase-rails`](https://github.com/supabase-ruby/supabase-rails) gem.
Hotwire (Turbo + Stimulus), Importmap, ViewComponent, Railsblocks, and
Tailwind v4. Ships sign-in, sign-up, password reset, OTP / magic-link, and
GitHub OAuth out of the box.

**Documentation:** <https://supabase-ruby.dev/reference/starterkits/hotwire>

## Quickstart

```bash
git clone https://github.com/supabase-ruby/starter-kit-hotwire.git
cd starter-kit-hotwire
cp .env.example .env   # fill in the Supabase values
bin/setup              # installs gems, prepares the database, starts bin/dev
```

Then open <http://localhost:3000>.

## License

[MIT](./LICENSE)
