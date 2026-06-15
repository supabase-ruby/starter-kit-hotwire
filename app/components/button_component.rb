class ButtonComponent < ViewComponent::Base
  def initialize(label:, type: :button, test_id: nil)
    @label = label
    @type = type
    @test_id = test_id
  end
end
