class AvatarComponent < ViewComponent::Base
  SIZES = {
    xs: "size-6 text-xs",
    sm: "size-8 text-sm",
    md: "size-10 text-sm",
    lg: "size-12 text-base",
    xl: "size-16 text-base"
  }.freeze

  def initialize(name: nil, initials: nil, src: nil, alt: nil, size: :md, circle: false, class_name: nil)
    @name = name
    @initials = initials || derive_initials(name)
    @src = src
    @alt = alt || name
    @size = SIZES.key?(size.to_sym) ? size.to_sym : :md
    @circle = circle
    @class_name = class_name
  end

  def css_classes
    [
      "relative flex-none isolate inline-flex items-center justify-center overflow-hidden font-medium select-none",
      "bg-zinc-200 text-zinc-800 dark:bg-zinc-600 dark:text-white",
      SIZES[@size],
      @circle ? "rounded-full" : "rounded-lg",
      @class_name
    ].compact.join(" ")
  end

  def show_image?
    @src.present?
  end

  def show_initials?
    !show_image? && @initials.present?
  end

  private

  def derive_initials(name)
    return nil if name.blank?

    name.to_s.split(" ").first(2).map { |word| word[0] }.join.upcase
  end
end
