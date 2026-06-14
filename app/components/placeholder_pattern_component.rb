class PlaceholderPatternComponent < ViewComponent::Base
  def initialize(class_name: nil, id: nil)
    @class_name = class_name
    @id = id || "pp-#{SecureRandom.hex(6)}"
  end
end
