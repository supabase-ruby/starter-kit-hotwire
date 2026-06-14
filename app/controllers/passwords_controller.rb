# frozen_string_literal: true

class PasswordsController < Supabase::Rails::PasswordsController
  layout "auth", only: %i[new edit]
end
