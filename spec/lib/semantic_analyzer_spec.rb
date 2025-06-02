require 'semantic_analyzer'

describe SemanticAnalyzer do
  subject do
    described_class.analyze(node) => [analyzed, _, _]
    analyzed
  end

  context 'detects undefined variables' do
    subject do
      described_class.analyze(node) => [_, _, [error]]
      error
    end

    let(:node) { var(:pepe) }

    it { is_expected.to be_a(SemanticAnalyzer::Error) }
    its(:message) { is_expected.to eql "Undefined variable 'pepe'" }
  end

  context 'variable declarations' do
    context 'valid declarations' do
      let(:node) { var_dec(:x, lit(42)) }

      it 'returns the analyzed node' do
        expect(subject).to be_a(AST::VariableDeclaration)
        expect(subject.name).to eql :x
        expect(subject.expression).to be_a(AST::Literal)
      end
    end

    context 'invalid declarations' do
      subject do
        described_class.analyze(node) => [_, _, [error]]
        error
      end

      context 'redeclaration in same scope' do
        let(:node) do
          prog(
            var_dec(:x, lit(42)),
            var_dec(:x, lit(43))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Already defined variable 'x'" }
      end
    end
  end
end
