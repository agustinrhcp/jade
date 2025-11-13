RSpec::Matchers.define :be_token do
  chain :of_type do |expected_type|
    @expected_type = expected_type
  end

  chain :with do |expected_value|
    @expected_value = expected_value
  end

  chain :at do |expected_range|
    @expected_range = expected_range
  end

  match do |actual|
    return false unless actual.is_a?(Jade::Token)

    matches = true
    matches &&= actual.type == @expected_type if defined?(@expected_type)
    matches &&= actual.value == @expected_value if defined?(@expected_value)
    matches &&= actual.range == @expected_range if defined?(@expected_range)
    matches
  end

  failure_message do |actual|
    {
      type: @expected_type,
      value: @expected_value,
      range: @expected_range
    }
      .reduce([]) do |acc, (attr, expected)|
        next acc unless defined?(expected)

        actual
          .public_send(attr)
          .then { it == expected ? acc : acc + ["expected #{attr} #{expected.inspect}, got #{it.inspect}"] }
      end
      .then do
        "expected #{actual.inspect} to be a token" +
          (it.empty? ? '' : " with:\n  - " + it.join("\n  - "))
      end
  end
end

