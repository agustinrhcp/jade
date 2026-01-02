RSpec.shared_context "single expression body" do
  subject do
    body = super()
    expect(body).to be_a(Jade::AST::Body)
    expect(body.expressions).to have(1).item
    body.expressions.last
  end
end

