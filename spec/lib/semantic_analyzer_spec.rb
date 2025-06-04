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

  context 'function calls' do
    context 'valid calls' do
      let(:node) do
        prog(
          fn_dec(:double, params(param(:x, :int)), :int, bin(var(:x), :*, lit(2))),
          fn_call(:double, lit(42))
        )
      end

      it 'returns the analyzed node' do
        expect(subject).to be_a(AST::Program)
        expect(subject.statements.last).to be_a(AST::FunctionCall)
        expect(subject.statements.last.name).to eql :double
        expect(subject.statements.last.arguments.first).to be_a(AST::Literal)
      end
    end

    context 'invalid calls' do
      subject do
        described_class.analyze(node) => [_, _, [error]]
        error
      end

      context 'undefined function' do
        let(:node) { fn_call(:unknown, lit(42)) }

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Undefined function 'unknown'" }
      end

      context 'wrong number of arguments' do
        let(:node) do
          prog(
            fn_dec(:double, params(param(:x, :int)), :int, bin(var(:x), :*, lit(2))),
            fn_call(:double, lit(42), lit(43))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Function 'double' expects 1 arguments, got 2" }
      end
    end
  end
end
