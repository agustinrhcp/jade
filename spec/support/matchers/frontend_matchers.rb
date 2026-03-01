RSpec::Matchers.define :have_node do |expected = nil|
  chain :of_type do |expected_type|
    @expected_type = expected_type
  end

  chain :with_symbol do |qualified_name|
    @expected_symbol = qualified_name
  end

  chain :with_attributes do |**attrs|
    @expected_attrs = attrs
  end

  match do |result|
    return false unless result.ok?

    result => Ok([node, _])
    @node = node

    if @expected_type
      return false unless values_match?(@expected_type, @node)
    end

    if @expected_symbol
      return false unless @node.respond_to?(:symbol)
      return false unless @node.symbol&.qualified_name == @expected_symbol
    end

    if @expected_attrs
      @expected_attrs.all? do |k, v|
        values_match?(v, @node.public_send(k))
      end
    else
      true
    end
  end

  failure_message do
    "expected node to match constraints, got #{@node.inspect}"
  end
end

RSpec::Matchers.define :have_registered do |name|
  match do |result|
    return false unless result.ok?

    result.value => Ok([_, registry])
    registry.lookup(name)
  end
end

RSpec.shared_context "body to single expression" do
  subject do
    super()
      .map do |(body, registry)|
        expect(body).to be_a(Jade::AST::Body)
        expect(body.expressions).to have(1).item
        [body.expressions.last, registry]
      end
  end
end
