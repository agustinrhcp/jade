require 'semantic_analyzer'

describe SemanticAnalyzer do
  subject do
    described_class.analyze(node) => [analyzed, _]
    analyzed
  end

  context 'detects undefined variables' do
    subject do
      described_class.analyze(node) => [_, [error]]
      error
    end

    let(:node) { var(:pepe) }

    it { is_expected.to be_a(SemanticAnalyzer::Error) }
    its(:message) { is_expected.to eql "Undefined variable 'pepe'" }
  end
end
