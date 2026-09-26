require "test_helper"

class ParameterFilterTest < ActiveSupport::TestCase
  test "personal data is filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    params = { fiscal_code: "LLVLC80A01H501ZD", phone: "333", birth_date: "1980-01-01",
               address: "Via Roma", email_address: "a@b.it", password: "x", first_name: "Alice" }

    filtered = filter.filter(params)

    %i[fiscal_code phone birth_date address email_address password].each do |key|
      assert_equal "[FILTERED]", filtered[key], key
    end
    assert_equal "Alice", filtered[:first_name]
  end
end
