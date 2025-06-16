require 'spec_helper'

require 'type_checker'

describe TypeChecker do
  let(:ctx) { Context.new }
  let(:result) { described_class.check(node, ctx) }
  subject { result => Ok([type, _]); type }

  context 'for an integer' do
    let(:node) { lit(2) }

    it { is_expected.to eql Type.int }
  end

  context 'for a boolean' do
    let(:node) { lit(false) }

    it { is_expected.to eql Type.bool }
  end

  context 'for a string' do
    let(:node) { lit('Hello') }

    it { is_expected.to eql Type.string }
  end

  context 'a unary operation' do
    context 'minus int' do
      let(:node) { uny(:-, lit(4)) }

      it { is_expected.to eql Type.int }
    end

    context 'minus bool' do
      let(:node) { uny(:-, lit(true)) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '-' not valid for Bool" }
    end

    context 'bang bool' do
      let(:node) { uny(:!, lit(true)) }

      it { is_expected.to eql Type.bool }
    end

    context 'bang string' do
      let(:node) { uny(:!, lit('Hello')) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '!' not valid for String" }
    end
  end

  context 'a binary operation' do
    context 'arithmetic operations' do
      context 'addition' do
        let(:node) { bin(lit(2), :+, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'subtraction' do
        let(:node) { bin(lit(5), :-, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'multiplication' do
        let(:node) { bin(lit(2), :*, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'division' do
        let(:node) { bin(lit(6), :/, lit(2)) }

        it { is_expected.to eql Type.int }
      end

      context 'invalid operands' do
        context 'string + int' do
          let(:node) { bin(lit('Hello'), :+, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '+' must be Int, got String" }
        end

        context 'bool * int' do
          let(:node) { bin(lit(true), :*, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '*' must be Int, got Bool" }
        end
      end
    end

    context 'comparison operations' do
      context 'less than' do
        let(:node) { bin(lit(2), :<, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'less than or equal' do
        let(:node) { bin(lit(2), :<=, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'greater than' do
        let(:node) { bin(lit(3), :>, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'greater than or equal' do
        let(:node) { bin(lit(3), :>=, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'equal' do
        let(:node) { bin(lit(2), :==, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'not equal' do
        let(:node) { bin(lit(2), :!=, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'invalid operands' do
        context 'string < int' do
          let(:node) { bin(lit('Hello'), :<, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '<' must be Int, got String" }
        end

        context 'bool == string' do
          let(:node) { bin(lit(true), :==, lit('Hello')) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Right operand of '==' must be Bool, got String" }
        end
      end
    end
  end

  context 'variables and declarations' do
    context 'a declared variable' do
      let(:node) { var('x') }
      let(:ctx) { Context.new.define_var('x', node).annotate_var('x', Type.int) }

      it { is_expected.to eql Type.int }
    end

    context 'an undeclared variable' do
      let(:node) { var('y') }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Undefined variable 'y'" }
    end

    context 'a variable declaration' do
      let(:node) { var_dec('z', lit(42)) }
      let(:ctx) { Context.new.define_var('z', node) }

      context 'the returned ctx' do
        subject { result => Ok([_, ctx]); ctx }

        it 'adds the variable type to the ctx' do
          expect(subject.resolve_var('z').type).to eql Type.int
        end
      end

      it { is_expected.to eql Type.int }

      context 'a string' do
        let(:node) { var_dec('z', lit('Alo')) }
        let(:ctx) { Context.new.define_var('z', node) }

        context 'the returned ctx' do
          subject { result => Ok([_, ctx]); ctx }

          it 'adds the variable type to the ctx' do
            type = subject.resolve_var('z').type
            expect(type).to eql Type.string
          end
        end

        it { is_expected.to eql Type.string }
      end
    end

    context 'function declarations' do
      let(:ctx) { Context.new.define_fn('double', node) }
      let(:node) { fn_dec('double', params(param('n', 'Int')), 'Int', bin(var('n'), :*, lit(2))) }

      it { is_expected.to be_a(Type::Function) }
      its(:parameters) { is_expected.to eql [Type.int] }
      its(:return_type) { is_expected.to eql Type.int }
    end
  end

  context 'function calls' do
    let(:fn_type) { Type::Function.new([Type.int], Type.int) }
    let(:ctx) { Context.new.define_fn('double', node).annotate_fn('double', fn_type) }

    context 'valid calls' do
      let(:node) { fn_call('double', lit(42)) }

      it { is_expected.to eql Type.int }
    end

    context 'invalid calls' do
      subject { result => Err(error); error }

      context 'argument type mismatch' do
        let(:node) { fn_call('double', lit('hello')) }

        its(:message) { is_expected.to eql "Expected argument 0 of type Int, got String" }
      end

      context 'multiple arguments with type mismatch' do
        let(:fn_type) { Type::Function.new([Type.int, Type.string], Type.int) }
        let(:node) { fn_call('double', lit(42), lit(43)) }

        its(:message) { is_expected.to eql "Expected argument 1 of type String, got Int" }
      end
    end
  end

  context 'record declaration' do
    let(:node) { rec('User', field('name', 'String'), field('age', 'Int')) }

    it { is_expected.to be_a(Type::Record) }
    its(:fields) { is_expected.to eql('name' => Type.string, 'age' => Type.int) }

    context 'empty record' do
      let(:node) { rec('Empty') }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to be_empty }
    end
  end

  context 'record instantiation' do
    let(:record_type) { Type::Record.new('User', {'name' => Type.string, 'age' => Type.int}) }
    let(:ctx) { Context.new.define_type('User', record_type) }

    context 'valid instantiation' do
      let(:node) { rec_new('User', field_set('name', lit('John')), field_set('age', lit(25))) }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to eql('name' => Type.string, 'age' => Type.int) }
    end

    context 'fields in different order' do
      let(:node) { rec_new('User', field_set('age', lit(25)), field_set('name', lit('John'))) }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to eql('name' => Type.string, 'age' => Type.int) }
    end

    context 'empty record instantiation' do
      let(:record_type) { Type::Record.new('Empty', {}) }
      let(:ctx) { Context.new.define_type('Empty', record_type) }
      let(:node) { rec_new('Empty') }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to be_empty }
    end

    context 'invalid instantiation' do
      subject { result => Err(errors); errors.first }

      context 'undefined record type' do
        let(:ctx) { Context.new }
        let(:node) { rec_new('Unknown', field_set('name', lit('John'))) }

        its(:message) { is_expected.to eql "Undefined record type 'Unknown'" }
      end

      context 'field type mismatch' do
        let(:node) { rec_new('User', field_set('name', lit(42)), field_set('age', lit(25))) }

        its(:message) { is_expected.to eql "Field 'name' expects String, got Int" }
      end

      context 'multiple field type mismatches' do
        let(:node) { rec_new('User', field_set('name', lit(42)), field_set('age', lit('twenty-five'))) }

        subject { result => Err(errors); errors }

        it 'reports all type mismatches' do
          expect(subject.size).to be >= 1
          error_messages = subject.map(&:message)
          expect(error_messages.any? { |msg| msg.include?("Field 'name' expects String, got Int") }).to be true
          expect(error_messages.any? { |msg| msg.include?("Field 'age' expects Int, got String") }).to be true
        end
      end
    end
  end

  context 'record access' do
    let(:ctx) do 
      Context.new
        .define_type('User', Type::Record.new(name: 'User',fields: { 'name' => Type.string }))
    end

    let(:node) { rec_access(rec_new('User', field_set('name', lit('John'))), 'name') }

    it { is_expected.to eql Type.string }
  end

  context 'anonymous records' do
    context 'valid anonymous record' do
      let(:node) { anon_rec(field_set('x', lit(42)), field_set('y', lit('hello'))) }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to eql('x' => Type.int, 'y' => Type.string) }
    end

    context 'empty anonymous record' do
      let(:node) { anon_rec() }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to be_empty }
    end

    context 'anonymous record with complex expressions' do
      let(:ctx) do
        Context.new.define_var('base', var_dec('base', lit(42))).annotate_var('base', Type.int)
      end

      let(:node) { anon_rec(field_set('sum', bin(lit(10), :+, var('base'))), field_set('doubled', bin(var('base'), :*, lit(2)))) }

      it { is_expected.to be_a(Type::Record) }
      its(:fields) { is_expected.to eql('sum' => Type.int, 'doubled' => Type.int) }
    end

    context 'invalid anonymous record' do
      subject { result => Err(error); error }

      context 'undefined variable in field expression' do
        let(:node) { anon_rec(field_set('value', var('undefined_var'))) }

        its(:message) { is_expected.to eql "Undefined variable 'undefined_var'" }
      end

      context 'type error in field expression' do
        let(:node) { anon_rec(field_set('invalid', bin(lit('hello'), :+, lit(42)))) }

        its(:message) { is_expected.to eql "Left operand of '+' must be Int, got String" }
      end
    end
  end

  context 'union type' do
    let(:node) { union('Color', variant('Red'), variant('Green'), variant('Blue')) }

    it { is_expected.to be_a(Type::Union) }

    describe 'its variants' do
      subject { result => Ok([type, _]); type.variants }

      it 'are checked' do
        expect(subject).to all(be_a(Type::VariantNullary))
        expect(subject.first.name).to eql 'Red'
        expect(subject.first.union_type_name).to eql 'Color'
        expect(subject[1].name).to eql 'Green'
        expect(subject[1].union_type_name).to eql 'Color'
        expect(subject[2].name).to eql 'Blue'
        expect(subject[2].union_type_name).to eql 'Color'
      end
    end
  end
end
