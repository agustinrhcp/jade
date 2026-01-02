RSpec.shared_context "with test compiler" do
  let(:test_compiler) { Jade::TestCompiler.new }
  after { test_compiler.cleanup }
end
