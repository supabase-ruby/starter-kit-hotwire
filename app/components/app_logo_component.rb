class AppLogoComponent < ViewComponent::Base
  BRAND_NAME = "Rails Starter Kit".freeze

  def initialize(name: BRAND_NAME)
    @name = name
  end
end
