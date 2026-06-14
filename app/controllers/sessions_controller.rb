# frozen_string_literal: true

class SessionsController < Supabase::Rails::SessionsController
  layout "auth", only: :new
end
