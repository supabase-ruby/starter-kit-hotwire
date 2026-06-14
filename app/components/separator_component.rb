class SeparatorComponent < ViewComponent::Base
  VARIANTS = {
    default: "bg-zinc-800/15 dark:bg-white/20",
    subtle: "bg-zinc-800/5 dark:bg-white/10"
  }.freeze

  def initialize(variant: :default, orientation: :horizontal, class_name: nil)
    @variant = VARIANTS.key?(variant.to_sym) ? variant.to_sym : :default
    @orientation = orientation.to_sym == :vertical ? :vertical : :horizontal
    @class_name = class_name
  end

  def css_classes
    [
      "border-0 shrink-0",
      VARIANTS[@variant],
      @orientation == :vertical ? "self-stretch w-px" : "h-px w-full",
      @class_name
    ].compact.join(" ")
  end

  def data_orientation
    @orientation.to_s
  end
end
