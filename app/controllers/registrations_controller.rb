# frozen_string_literal: true

class RegistrationsController < Supabase::Rails::RegistrationsController
  layout "auth", only: :new
end
