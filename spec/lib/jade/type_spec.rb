require 'spec_helper'

require 'jade'

module Jade
  describe Type do
    include SymbolFactory

    describe '.from_symbol' do
      let(:result) { described_class.from_symbol(symbol, registry, Frontend::TypeChecking::VarGen.new) }
      subject { result[0] }

      let(:registry) do
        Stdlib
          .load(Registry.new)
          .add_module(entry)
      end

      describe 'the id function: x -> x' do
        let(:symbol) do
          fn_sym('__Test__', 'id')
            .with(params: { x: var_sym('a') })
            .with(return_type: var_sym('a'))
        end

        let(:entry) { Registry.entry('__Test__').define(symbol) }

        it { is_expected.to be_a(Type::Function) }

        it 'has the same type as argument and as return type' do
          expect(subject.args.first).to eql subject.return_type
        end
      end

      describe 'the function with constructor: Int, Int -> Int' do
        let(:symbol) do
          fn_sym('__Test__', 'add')
            .with(params: { a: type_sym('Basics', 'Int'), b: type_sym('Basics', 'Int') })
            .with(return_type: type_sym('Basics', 'Int'))
        end

        let(:entry) { Registry.entry('__Test__').define(symbol) }

        it { is_expected.to be_a(Type::Function) }
        its(:args) { is_expected.to have(2).items.and all(be_a(Type::Application))}
      end

      describe 'type application: Maybe(a)' do
        let(:symbol) do
          type_sym('Maybe', 'Maybe').with(args: [var_sym('a')])
        end

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Application) }
        its(:constructor) { is_expected.to eql Type.constructor('Maybe.Maybe') }
        its(:args) { is_expected.to have(1).item }

        describe 'the arg' do
          subject { super().args.first }
          it { is_expected.to be_a(Type::Var).and have_attributes(name: 'a') }
        end
      end

      describe 'the function with type application: a -> Maybe(a)' do
        let(:symbol) do
          fn_sym('__Test__', 'to_maybe')
            .with(params: { maybe: var_sym('a') })
            .with(return_type: type_sym('Maybe', 'Maybe').with(args: [var_sym('a')]))
        end

        let(:entry) { Registry.entry('__Test__').define(symbol) }

        it { is_expected.to be_a(Type::Function) }
        it 'function arg and application arg are the same' do
          expect(subject.args.first).to eql subject.return_type.args.first
        end
      end

      describe 'variant symbol: Nothing' do
        let(:symbol) { Symbol::ValueRef['Maybe', 'Nothing'] }

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Application) }

        its(:constructor) { is_expected.to be_a(Type::Constructor).and have_attributes(name: 'Maybe.Maybe') }
        its(:args) { is_expected.to contain_exactly(be_a(Type::Var).and(have_attributes(name: 'a'))) }
      end

      describe 'variant symbol: Just' do
        let(:symbol) { Symbol::ValueRef['Maybe', 'Just'] }

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Function) }
        its(:return_type) { is_expected.to be_a(Type::Application) }

        its(:args) { is_expected.to have(1).item }

        it 'function arg and application arg are the same' do
          expect(subject.args.first).to eql subject.return_type.args.first
        end

        describe 'the return type' do
          subject { super().return_type }
          it { is_expected.to be_a(Type::Application) }

          its(:constructor) { is_expected.to be_a(Type::Constructor).and have_attributes(name: 'Maybe.Maybe') }
          its(:args) { is_expected.to contain_exactly(be_a(Type::Var).and(have_attributes(name: 'a'))) }
        end
      end

      describe 'variant symbol: Ok' do
        let(:symbol) { Symbol::ValueRef['Result', 'Ok'] }

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Function) }
        it 'function arg and first application arg are the same' do
          expect(subject.args.first).to eql subject.return_type.args.first
        end

        describe 'the return type' do
          subject { super().return_type }
          its(:args) { is_expected.to have(2).items }
        end
      end

      describe 'variant symbol: Err' do
        let(:symbol) { Symbol::ValueRef['Result', 'Err'] }

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Function) }
        it 'function arg and second application arg are the same' do
          expect(subject.args.first).to eql subject.return_type.args.last
        end

        describe 'the return type' do
          subject { super().return_type }
          its(:args) { is_expected.to have(2).items }
        end
      end

      describe 'type application: Maybe(Maybe(a))' do
        let(:symbol) do
          type_sym('Maybe', 'Maybe')
            .with(
              args: [
                type_sym('Maybe', 'Maybe')
                  .with(args: [var_sym('a')])
              ]
            )
        end

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Application) }
        its(:constructor) { is_expected.to eql Type.constructor('Maybe.Maybe') }
        its(:args) { is_expected.to have(1).item }

        describe 'the arg' do
          subject { super().args.first }

          it do
            is_expected
              .to be_a(Type::Application)
              .and have_attributes(constructor: Type.constructor('Maybe.Maybe'))
          end
        end
      end

      describe 'type application with var constructor: f(a)' do
        let(:symbol) do
          Symbol::PartialApplication.new(
            constructor: var_sym('f'),
            args: [var_sym('a')],
            span: nil,
          )
        end

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Application) }
        its(:constructor) { is_expected.to be_a(Type::Var).and have_attributes(name: 'f') }
        its(:args) { is_expected.to have(1).item }

        it 'arg is a type var' do
          expect(subject.args.first).to be_a(Type::Var).and have_attributes(name: 'a')
        end

        context 'via Symbol.parse' do
          let(:symbol) { Symbol.parse('f(a)') }

          it { is_expected.to be_a(Type::Application) }
          its(:constructor) { is_expected.to be_a(Type::Var).and have_attributes(name: 'f') }
        end
      end

      describe 'type application with repeated vars: Result(a, a)' do
        let(:symbol) do
          type_sym('Result', 'Result')
            .with(args: [var_sym('a'), var_sym('a')])
        end

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Application) }
        its(:constructor) { is_expected.to eql Type.constructor('Result.Result') }
        its(:args) { is_expected.to have(2).item }

        it 'reuses the same type var for both arguments' do
          left, right = subject.args
          expect(left).to eql(right)
        end
      end

      describe 'interface function: eq(a, a) -> Bool constrained by Eq' do
        let(:interface_sym) do
          Symbol::Interface.new(
            module_name: '__Iface__',
            name: 'Eq',
            type_param: var_sym('a'),
            functions: [],
            default: nil,
            decl_span: nil,
          )
        end

        let(:symbol) do
          Symbol::InterfaceFunction.new(
            module_name: '__Test__',
            name: 'eq',
            interface: Symbol::TypeRef['__Iface__', 'Eq'],
            params: [var_sym('a'), var_sym('a')],
            return_type: type_sym('Basics', 'Bool'),
            decl_span: nil,
          )
        end

        let(:entry) { Registry.entry('__Test__').define(symbol) }

        let(:registry) do
          Stdlib
            .load(Registry.new)
            .add_module(Registry.entry('__Iface__').define(interface_sym))
            .add_module(entry)
        end

        it { is_expected.to be_a(Type::Function) }
        its(:args) { is_expected.to have(2).items }

        describe 'constraints' do
          subject { result[1] }

          it { is_expected.to have(1).item }
          its(:first) { is_expected.to be_a(Type::Constraint).and have_attributes(interface: '__Iface__.Eq') }
        end
      end

      describe 'function from anonymous record with type param { id: id } -> id' do
        let(:symbol) do
          fn_sym('__Test__', "id")
            .with(params: { "rec" => rec_type_sym.with(fields: { 'id' => var_sym('id') })})
            .with(return_type: var_sym('id'))
        end

        let(:entry) { Registry.entry('__Test__') }

        it { is_expected.to be_a(Type::Function) }

        it 'reuses the field arg for the return type' do
          expect(subject.args.first.fields['id']).to eql subject.return_type
        end
        its(:unbound_vars) { is_expected.to have(1).items }
      end
    end

    describe '.var' do
      subject { Type.var('a') }

      its(:unbound_vars) { is_expected.to eql [subject] }
      its(:to_s) { 'a' }
    end

    describe '.function' do
      let(:a) { Type.var('a') }
      subject { Type.function([a], a) }

      its(:unbound_vars) { is_expected.to eql [a] }
      its(:to_s) { is_expected.to eql '(a) -> a' }
    end
  end
end
