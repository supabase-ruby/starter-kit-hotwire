class ButtonComponent < ViewComponent::Base
  def initialize(label:, type: :button)
    @label = label
    @type = type
  end
end
