class SidebarComponent < ViewComponent::Base
  def initialize(user:, current_path: nil)
    @user = user
    @current_path = current_path
  end

  def nav_items
    [
      { label: "Dashboard", href: helpers.dashboard_path, icon: "layout-grid" },
      { label: "Settings",  href: "/settings/profile",   icon: "settings" }
    ]
  end

  def current?(href)
    return false if @current_path.blank?

    @current_path == href || @current_path.start_with?("#{href}/")
  end

  def link_classes(active:)
    base = "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors"
    state = if active
      "bg-zinc-200/70 text-zinc-900 dark:bg-zinc-800 dark:text-white"
    else
      "text-zinc-700 hover:bg-zinc-200/50 dark:text-zinc-300 dark:hover:bg-zinc-800/70"
    end
    "#{base} #{state}"
  end
end
