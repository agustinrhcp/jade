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
                Type.function({ 'a' => Type.int, 'b' => Type.int }, Type.int),
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
    end
  end
end
