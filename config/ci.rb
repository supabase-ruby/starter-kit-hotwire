# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gem audit", "bin/bundler-audit"

  step "Tests: Rails", "bin/rails test"
  step "Tests: System", "bin/rails test:system"

  if ENV["SKIP_E2E"] == "1"
    heading "Tests: E2E (skipped)", "SKIP_E2E=1 — unset to include the end-to-end suite.", type: :subtitle
  elsif !system("docker info > /dev/null 2>&1")
    heading "Tests: E2E (skipped)", "Docker is not running — start Docker Desktop to include the end-to-end suite.", type: :subtitle
  else
    step "Tests: E2E", "bin/e2e"
  end
end
