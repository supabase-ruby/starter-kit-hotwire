ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Exclude end-to-end tests from the default `bin/rails test` discovery glob.
# E2E tests live under `test/e2e/` and require a running local Supabase stack
# (started via `bin/e2e`). The Rails default already excludes system/dummy/
# fixtures; we add `e2e` to the same brace so passing an explicit path —
# `bin/rails test test/e2e` — still picks them up (Rails skips the exclude
# whenever a path argument is provided).
ENV["DEFAULT_TEST_EXCLUDE"] ||= "test/{system,dummy,fixtures,e2e}/**/*_test.rb"

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
