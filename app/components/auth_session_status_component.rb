class AuthSessionStatusComponent < ViewComponent::Base
  def initialize(status:, class_name: nil)
    @status = status
    @class_name = class_name
  end

  def render?
    @status.present?
  end

  def css_classes
    [ "font-medium text-sm text-green-600", @class_name ].compact.join(" ")
  end
end
