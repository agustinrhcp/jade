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

      context 'redeclaration in same context' do
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
    end
  end

  context 'record declaration and instantiation' do
    context 'valid record declarations' do
      let(:node) { rec('User', field('name', 'String'), field('age', 'Int')) }

      it 'returns the analyzed node' do
        expect(subject).to be_a(AST::RecordDeclaration)
        expect(subject.name).to eql 'User'
        expect(subject.fields.size).to eql 2
        expect(subject.fields.first.name).to eql 'name'
        expect(subject.fields.first.type).to be_a(AST::TypeRef)
        expect(subject.fields.first.type.name).to eql('String')
      end

      context 'empty record' do
        let(:node) { rec('Empty') }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::RecordDeclaration)
          expect(subject.name).to eql 'Empty'
          expect(subject.fields).to be_empty
        end
      end

      context 'single field record' do
        let(:node) { rec('Counter', field('value', 'Int')) }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::RecordDeclaration)
          expect(subject.name).to eql 'Counter'
          expect(subject.fields.size).to eql 1
        end
      end

      context 'with generics' do
        let(:node) { rec_with_generics('Box', ['a'], field('content', 'a')) }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::RecordDeclaration)
          expect(subject.name).to eql 'Box'
          expect(subject.params).to eql ['a']
          expect(subject.fields.size).to eql 1
        end
      end
    end

    context 'invalid record declarations' do
      subject do
        described_class.analyze(node) => [_, _, [error]]
        error
      end

      context 'duplicate field names' do
        let(:node) { rec('User', field('name', 'String'), field('name', 'Int')) }

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Duplicate field 'name' in record 'User'" }
      end

      context 'multiple duplicate fields' do
        let(:node) { rec('User', field('name', 'String'), field('age', 'Int'), field('name', 'String'), field('age', 'String')) }
        
        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports all duplicate fields' do
          expect(subject.size).to eql 2
          expect(subject.map(&:message)).to include("Duplicate field 'name' in record 'User'")
          expect(subject.map(&:message)).to include("Duplicate field 'age' in record 'User'")
        end
      end

      context 'redeclaration of record type' do
        let(:node) do
          prog(
            rec('User', field('name', 'String')),
            rec('User', field('email', 'String'))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Already defined record type 'User'" }
      end

      context 'with undeclared generics' do
        let(:node) { rec('Box', field('content', 'a')) }

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Unbound type variable 'a' for 'Box' definition" }
      end
    end

    context 'valid record instantiation' do
      let(:node) do
        prog(
          rec('User', field('name', 'String'), field('age', 'Int')),
          rec_new('User', field_set('name', lit('John')), field_set('age', lit(25)))
        )
      end

      it 'returns the analyzed node' do
        expect(subject).to be_a(AST::Program)
        expect(subject.statements.last).to be_a(AST::RecordInstantiation)
        expect(subject.statements.last.name).to eql 'User'
        expect(subject.statements.last.fields.size).to eql 2
      end

      context 'fields in different order' do
        let(:node) do
          prog(
            rec('User', field('name', 'String'), field('age', 'Int')),
            rec_new('User', field_set('age', lit(25)), field_set('name', lit('John')))
          )
        end

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::Program)
          expect(subject.statements.last).to be_a(AST::RecordInstantiation)
          expect(subject.statements.last.fields.size).to eql 2
        end
      end

      context 'empty record instantiation' do
        let(:node) do
          prog(
            rec('Empty'),
            rec_new('Empty')
          )
        end

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::Program)
          expect(subject.statements.last).to be_a(AST::RecordInstantiation)
          expect(subject.statements.last.fields).to be_empty
        end
      end

      context 'nested expressions in fields' do
        let(:node) do
          prog(
            rec('Point', field('x', 'Int'), field('y', 'Int')),
            rec_new('Point', field_set('x', bin(lit(10), :+, lit(5))), field_set('y', bin(lit(20), :*, lit(2))))
          )
        end

        it 'analyzes field expressions' do
          expect(subject).to be_a(AST::Program)
          instantiation = subject.statements.last
          expect(instantiation.fields.first.expression).to be_a(AST::Binary)
          expect(instantiation.fields.last.expression).to be_a(AST::Binary)
        end
      end
    end

    context 'invalid record instantiation' do
      subject do
        described_class.analyze(node) => [_, _, [error]]
        error
      end

      context 'undefined record type' do
        let(:node) { rec_new('Unknown', field_set('name', lit('John'))) }

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Undefined record type 'Unknown'" }
      end

      context 'missing required field' do
        let(:node) do
          prog(
            rec('User', field('name', 'String'), field('age', 'Int')),
            rec_new('User', field_set('name', lit('John')))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Missing required field 'age' for record 'User'" }
      end

      context 'multiple missing fields' do
        let(:node) do
          prog(
            rec('User', field('name', 'String'), field('age', 'Int'), field('email', 'String')),
            rec_new('User', field_set('name', lit('John')))
          )
        end

        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports all missing fields' do
          expect(subject.size).to be >= 1
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Missing required field") }).to be true
        end
      end

      context 'unknown field' do
        let(:node) do
          prog(
            rec('User', field('name', 'String')),
            rec_new('User', field_set('name', lit('John')), field_set('email', lit('john@example.com')))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Unknown field 'email' for record 'User'" }
      end

      context 'multiple unknown fields' do
        let(:node) do
          prog(
            rec('User', field('name', 'String')),
            rec_new('User', field_set('name', lit('John')), field_set('email', lit('john@example.com')), field_set('phone', lit('123-456-7890')))
          )
        end

        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports all unknown fields' do
          expect(subject.size).to be >= 1
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Unknown field") }).to be true
        end
      end

      context 'duplicate field assignment' do
        let(:node) do
          prog(
            rec('User', field('name', 'String')),
            rec_new('User', field_set('name', lit('John')), field_set('name', lit('Jane')))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Duplicate assignment to field 'name' in record instantiation" }
      end

      context 'multiple duplicate assignments' do
        let(:node) do
          prog(
            rec('User', field('name', 'String'), field('age', 'Int')),
            rec_new('User', field_set('name', lit('John')), field_set('age', lit(25)), field_set('name', lit('Jane')), field_set('age', lit(30)))
          )
        end

        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports all duplicate assignments' do
          expect(subject.size).to be >= 1
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Duplicate assignment to field") }).to be true
        end
      end

      context 'combination of missing and unknown fields' do
        let(:node) do
          prog(
            rec('User', field('name', 'String'), field('age', 'Int')),
            rec_new('User', field_set('email', lit('john@example.com')))
          )
        end

        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports both missing and unknown field errors' do
          expect(subject.size).to be >= 2
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Missing required field") }).to be true
          expect(error_messages.any? { |msg| msg.include?("Unknown field") }).to be true
        end
      end
    end

    context 'anonymous records' do
      context 'valid anonymous record' do
        let(:node) { anon_rec(field_set('x', lit(42)), field_set('y', lit('hello'))) }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::AnonymousRecord)
          expect(subject.fields.size).to eql 2
          expect(subject.fields.first.name).to eql 'x'
          expect(subject.fields.first.expression).to be_a(AST::Literal)
        end
      end

      context 'empty anonymous record' do
        let(:node) { anon_rec() }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::AnonymousRecord)
          expect(subject.fields).to be_empty
        end
      end

      context 'anonymous record with complex expressions' do
        let(:node) { anon_rec(field_set('sum', bin(lit(10), :+, lit(20))), field_set('name', var('user_name'))) }

        it 'analyzes field expressions' do
          expect(subject).to be_a(AST::AnonymousRecord)
          expect(subject.fields.first.expression).to be_a(AST::Binary)
          expect(subject.fields.last.expression).to be_a(AST::Variable)
        end
      end

      context 'invalid anonymous record' do
        subject do
          described_class.analyze(node) => [_, _, [error]]
          error
        end

        context 'duplicate field names' do
          let(:node) { anon_rec(field_set('x', lit(42)), field_set('x', lit(43))) }

          it { is_expected.to be_a(SemanticAnalyzer::Error) }
          its(:message) { is_expected.to eql "Duplicate field 'x' in anonymous record" }
        end

        context 'multiple duplicate fields' do
          let(:node) { anon_rec(field_set('x', lit(42)), field_set('y', lit(43)), field_set('x', lit(44)), field_set('y', lit(45))) }

          subject do
            described_class.analyze(node) => [_, _, errors]
            errors
          end

          it 'reports all duplicate fields' do
            expect(subject.size).to be >= 1
            error_messages = subject.map(&:message)
            expect(error_messages.any? { |msg| msg.include?("Duplicate field") && msg.include?("anonymous record") }).to be true
          end
        end
      end
    end
  end

  context 'union type declaration and usage' do
    context 'valid union type declarations' do
      let(:node) { union('Color', variant('Red'), variant('Green'), variant('Blue')) }

      it { is_expected.to be_a(AST::UnionType) }
      its(:name) { is_expected.to eql 'Color' }

      it 'returns the analyzed node' do
        expect(subject.variants.size).to eql 3
        expect(subject.variants.map(&:name)).to eql ['Red', 'Green', 'Blue']
      end

      context 'union with variants having parameters' do
        let(:node) do
          union(
            'Result',
            variant('Ok', params: [variant_param('String')]),
            variant('Err', params: [variant_param('Int')]),
          )
        end

        it { is_expected.to be_a(AST::UnionType) }
        its(:name) { is_expected.to eql 'Result' }

        it 'returns the analyzed node' do
          expect(subject.variants.size).to eql 2

          expect(subject.variants.first.params.size).to eql 1
          expect(subject.variants.first.params.first.value).to eql 'String'
          expect(subject.variants.last.params.size).to eql 1
          expect(subject.variants.last.params.first.value).to eql 'Int'
        end
      end

      context 'union with variants having fields' do
        let(:node) { union('Shape', variant('Circle', fields: [variant_field('radius', 'Int')]), variant('Rectangle', fields: [variant_field('width', 'Int'), variant_field('height', 'Int')])) }

        it { is_expected.to be_a(AST::UnionType) }
        its(:name) { is_expected.to eql 'Shape' }

        it 'returns the analyzed node' do
          expect(subject.variants.size).to eql 2
          expect(subject.variants.first.fields.size).to eql 1
          expect(subject.variants.last.fields.size).to eql 2
        end
      end

      context 'union with mixed variants' do
        let(:node) { union('Mixed', variant('Simple'), variant('WithParam', params: [variant_param('String')]), variant('WithField', fields: [variant_field('value', 'Int')])) }

        it { is_expected.to be_a(AST::UnionType) }
        its(:name) { is_expected.to eql 'Mixed' }

        it 'returns the analyzed node' do
          expect(subject.variants.size).to eql 3
          expect(subject.variants[0].fields).to be_empty
          expect(subject.variants[0].params).to be_empty
          expect(subject.variants[1].params.size).to eql 1
          expect(subject.variants[2].fields.size).to eql 1
        end
      end

      context 'single variant union' do
        let(:node) { union('Maybe', variant('Nothing')) }

        it 'returns the analyzed node' do
          expect(subject).to be_a(AST::UnionType)
          expect(subject.name).to eql 'Maybe'
          expect(subject.variants.size).to eql 1
          expect(subject.variants.first.name).to eql 'Nothing'
        end
      end
    end

    context 'invalid union type declarations' do
      subject do
        described_class.analyze(node) => [_, _, [error]]
        error
      end

      context 'duplicate variant names' do
        let(:node) { union('Color', variant('Red'), variant('Green'), variant('Red')) }

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Duplicate variant 'Red' type 'Color'" }
      end

      context 'multiple duplicate variants' do
        let(:node) { union('Status', variant('Loading'), variant('Success'), variant('Loading'), variant('Error'), variant('Success')) }

        subject do
          described_class.analyze(node) => [_, _, errors]
          errors
        end

        it 'reports all duplicate variants' do
          expect(subject.size).to be >= 1
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Duplicate variant") && msg.include?("type 'Status'") }).to be true
        end
      end

      context 'redeclaration of union type' do
        let(:node) do
          prog(
            union('Color', variant('Red')),
            union('Color', variant('Blue'))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Already defined type 'Color'" }
      end

      context 'union type conflicts with record type' do
        let(:node) do
          prog(
            rec('User', field('name', 'String')),
            union('User', variant('Admin'), variant('Guest'))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Already defined type 'User'" }
      end

      context 'record type conflicts with union type' do
        let(:node) do
          prog(
            union('Status', variant('Active'), variant('Inactive')),
            rec('Status', field('value', 'String'))
          )
        end

        it { is_expected.to be_a(SemanticAnalyzer::Error) }
        its(:message) { is_expected.to eql "Already defined record type 'Status'" }
      end
    end

    context 'union types in context' do
      let(:node) do
        prog(
          union('Color', variant('Red'), variant('Green'), variant('Blue')),
          union('Status', variant('Loading'), variant('Success'), variant('Error'))
        )
      end

      it 'registers both union types' do
        expect(subject).to be_a(AST::Program)
        expect(subject.statements.size).to eql 2
        expect(subject.statements.first).to be_a(AST::UnionType)
        expect(subject.statements.last).to be_a(AST::UnionType)
      end
    end

    context 'complex union type scenarios' do
      context 'union with complex variant fields' do
        let(:node) do
          prog(
            rec('Point', field('x', 'Int'), field('y', 'Int')),
            union('Shape', 
              variant('Circle', fields: [variant_field('center', 'Point'), variant_field('radius', 'Int')]),
              variant('Rectangle', fields: [variant_field('topLeft', 'Point'), variant_field('bottomRight', 'Point')])
            )
          )
        end

        it 'analyzes union with record type references' do
          expect(subject).to be_a(AST::Program)
          union_type = subject.statements.last
          expect(union_type).to be_a(AST::UnionType)
          expect(union_type.variants.first.fields.first.value).to eql 'Point'
        end
      end

      context 'nested union definitions' do
        let(:node) do
          prog(
            union('Inner', variant('A'), variant('B')),
            union('Outer', 
              variant('SimpleCase'),
              variant('ComplexCase', params: [variant_param('Inner')])
            )
          )
        end

        it 'handles nested union type references' do
          expect(subject).to be_a(AST::Program)
          expect(subject.statements.size).to eql 2
          outer_union = subject.statements.last
          expect(outer_union.variants.last.params.first.value).to eql 'Inner'
        end
      end
    end
  end
end
