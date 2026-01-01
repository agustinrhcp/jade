require 'spec_helper'

require 'jade/symbol'
require 'jade/type'
require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  module Frontend
    describe TypeChecking do
      let(:source) do
        Source.new(uri: 'test', text:)
      end

      let(:type_check) do
        Lexer
          .tokenize(source)
          .then { Parser.parse(it) }
          .and_then { Frontend.run_up_to_semantic_analysis(it) }
          .and_then { TypeChecking.check(*it) }
      end

      subject { type_check }

      context 'literals' do
        let(:text) do
          <<~JADE
            42
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
      end

      context 'a function declaration' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.unit }
        its(:errors) { is_expected.to be_empty }

        context 'it binds the function to the env' do
          subject { super().env }

          its(:bindings) do
            is_expected.to have_key('add')
            is_expected.to include(
              'add' => TypeChecking::Scheme[
                [],
                Type.function([Type.int, Type.int], Type.int),
              ]
            )
          end
        end

        context 'with a longer body (so a Body node)' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                c = 10
                c
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end

        context 'when type return type and the body types mismatch' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                "Hello"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a(TypeChecking::FunctionBodyTypeMismatchError) }
            its(:message) { is_expected.to include('it returns String but its signature says it should be Int') }
          end
        end
      end

      context 'a variable binding' do
        let(:text) do
          <<~JADE
            hello = "Hola"
          JADE
        end

        its(:type) { is_expected.to eql Type.string }
        its(:errors) { is_expected.to be_empty }

        context 'it binds the variable to the env' do
          subject { super().env }

          its(:bindings) do
            is_expected.to have_key('hello')
            is_expected.to include('hello' => TypeChecking::Scheme[[], Type.string])
          end
        end
      end

      context 'infix application' do
        let(:text) do
          <<~JADE
            2 * 2 + 3 * 3
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when calling with the wrong params' do
          let(:text) do
            <<~JADE
              2 * "Hello"
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a(TypeChecking::InfixApplicationTypeMismatchError) }
            its(:message) { is_expected.to include('Left side of (*) expects Int but found String') }
          end
        end
      end

      context 'a function declaration' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a + b
            end
            add(1, 2)
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when calling with the wrong params' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                a + b
              end
              add(1, "Hello")
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a(TypeChecking::FunctionCallTypeMismatchError) }
            its(:message) { is_expected.to include('Function call mismatch, expected (Int, Int) -> Int but found (Int, String) -> Int') }
          end
        end
      end

      context 'type def and reference' do
        let(:text) do
          <<~JADE
            type Maybe(a) = Just(a) | Nothing
            Just
          JADE
        end

        its(:type) { is_expected.to eql Type.function([Type.var('t1')], Type.constructor('__Test__.Maybe').apply([Type.var('t1')])) }
        its(:errors) { is_expected.to be_empty }

        describe 'and call' do
          let(:text) do
            <<~JADE
              type Maybe(a) = Just(a) | Nothing
              Just(12)
            JADE
          end

          its(:type) { is_expected.to eql Type.constructor('__Test__.Maybe').apply([Type.int]) }
          its(:errors) { is_expected.to be_empty }
        end

        describe 'and call with different type application' do
          let(:text) do
            <<~JADE
              type Maybe(a) = Just(a) | Nothing
              Just(12)
              Just("Hello")
            JADE
          end

          its(:type) { is_expected.to eql Type.constructor('__Test__.Maybe').apply([Type.string]) }
          its(:errors) { is_expected.to be_empty }
        end

        describe 'and call with wrong params' do
          let(:text) do
            <<~JADE
              type Maybe(a) = Just(a, a) | Nothing
              Just(12, "Hello")
            JADE
          end

          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }

            its(:message) { is_expected.to eql "Function call mismatch, expected (Int, Int) -> Maybe(Int) but found (Int, String) -> Maybe(Int)" }
          end
        end
      end

      context 'if then else' do
        let(:text) do
          <<~JADE
            if String.is_empty("") then
              1
            else
              2
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when the condition is not a boolean' do
          let(:text) do
            <<~JADE
              if "" then
                1
              else
                2
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }

            it { is_expected.to be_a(TypeChecking::IfConditionTypeMismatchError) }
            its(:message) { is_expected.to include('If condition expects Bool but found String') }
          end
        end

        context 'when the branches have different types' do
          let(:text) do
            <<~JADE
              if String.is_empty("") then
                1
              else
                "two"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }

            it { is_expected.to be_a(TypeChecking::IfBranchesTypeMismatchError) }
            its(:message) { is_expected.to include('If branches must preturn the same type. The if branch produces Int but the else branch produces String') }
          end
        end
      end

      context 'case of' do
        let(:text) do
          <<~JADE
            case 1 of
            1 then 1
            _ then 2
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when pattern type is invalid' do
          let(:text) do
            <<~JADE
              case 1 of
              "" then 1
              _ then 2
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a TypeChecking::PatternTypeMismatchError }

            its(:message) { is_expected.to include 'Pattern is trying to match Int with String' }
          end
        end

        context 'when branches are of different type' do
          let(:text) do
            <<~JADE
              case 1 of
              1 then 1
              _ then "two"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a TypeChecking::CaseOfBranchesTypeMismatchError }

            its(:message) { is_expected.to include 'First branch of this case statement is Int but branch 2 is String' }
          end
        end
      end
    end
  end
end
