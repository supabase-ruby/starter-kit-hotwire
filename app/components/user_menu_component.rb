class UserMenuComponent < ViewComponent::Base
  PLACEMENTS = %i[bottom top].freeze

  def initialize(user:, avatar_src: nil, placement: :bottom)
    @user = user
    @avatar_src = avatar_src
    @placement = PLACEMENTS.include?(placement) ? placement : :bottom
  end

  def display_name
    @user.name.presence || @user.email
  end

  def initials
    @user.initials.presence || derive_initials_from_email
  end

  def settings_path
    "/settings/profile"
  end

  def wrapper_classes
    base = "relative text-left"
    @placement == :top ? "#{base} block w-full" : "#{base} inline-block"
  end

  def menu_classes
    base = "hidden absolute z-50 rounded-md border border-zinc-200 bg-white shadow-lg ring-1 ring-black/5 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900"
    if @placement == :top
      "#{base} inset-x-0 bottom-full mb-2 origin-bottom"
    else
      "#{base} right-0 mt-2 w-60 origin-top-right"
    end
  end

  private

  def derive_initials_from_email
    @user.email.to_s[0, 2].upcase
  end
end
