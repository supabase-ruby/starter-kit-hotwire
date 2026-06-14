# frozen_string_literal: true

class OtpController < Supabase::Rails::OtpController
  layout "auth", only: %i[new verify]
end
