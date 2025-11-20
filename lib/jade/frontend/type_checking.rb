require 'jade/frontend/type_checking/substitution'
require 'jade/frontend/type_checking/unification'
require 'jade/frontend/type_checking/generalization'
require 'jade/frontend/type_checking/inference'

module Jade
  module Frontend
    module TypeChecking
      extend self

      Result = Data.define(:type, :substitution, :env, :errors) do
        def and_unify(actual, &block)
          case Unification.unify(type, actual)
          in Ok(sub)
            compose_substitution(sub)
              .apply
          in Err(error)
            add_errors([block.call(error)])
              .with(type: error.actual)
          end
        end

        def add_errors(more_errors)
          with(errors: errors + more_errors)
        end

        def compose_substitution(sub)
          with(substitution: substitution.compose(sub))
        end

        def apply
          with(type: substitution.apply(type))
        end

        def to_result
          if errors.any?
            Err[errors]
          else
            Ok[[type, env]]
          end
        end
      end

      def check_repl(node, registry, env = Env.new, var_gen = VarGen.new)
        check(node, registry, env, var_gen)
          .to_result
      end

      def check(node, registry, env = Env.new, var_gen = VarGen.new)
        case node
        in AST::Literal
          infer_literal(node, registry, env, var_gen)

        in AST::FunctionDeclaration
          Inference::FunctionDeclaration.infer(node, registry, env, var_gen)

        in AST::InfixApplication
          Inference::InfixApplication.infer(node, registry, env, var_gen)

        in AST::FunctionCall
          Inference::FunctionCall.infer(node, registry, env, var_gen)

        in AST::VariableReference
          infer_variable_reference(node, registry, env, var_gen)

        in AST::VariableBinding
          infer_variable_binding(node, registry, env, var_gen)

        in AST::Body
          infer_body(node, registry, env, var_gen)
        end
      end

      private

      def type_from_symbol(symbol, registry)
        case symbol
        in Symbol::TypeRef | Symbol::ValueRef
          registry
            .lookup(symbol)
            .then { type_from_symbol(it, registry) }

        in Symbol::Union
          Type.constructor(symbol.qualified_name)

        in Symbol::Function | Symbol::StdlibFunction
          Type
            .function(
              symbol.params.transform_values { type_from_symbol(it, registry) },
              type_from_symbol(symbol.return_type, registry)
            )
        end
      end

      def infer_variable_reference(node, registry, env, var_gen)
        node => AST::VariableReference(name:)

        env
          .bindings[name]
          .then { instantiate(it) }
          .then { Result[it, Substitution.new, env, []] }
      end

      def infer_literal(node, registry, env, var_gen)
        node => AST::Literal(symbol:)

        type_from_symbol(symbol, registry)
          .then { Result[it, Substitution.new, env, []] }
      end

      def infer_variable_binding(node, registry, env, var_gen)
        node => AST::VariableBinding(name:, expression:)

        check(expression, registry, env, var_gen)
          .then { it.with(env: it.env.bind(name, generalize(it.type))) }
      end

      def infer_body(node, registry, env, var_gen)
        node => AST::Body(expressions:)

        expressions
          .reduce(Result[Type.unit, Substitution.new, env, []]) do |acc, expr|
            check(expr, registry, acc.env, var_gen)
              .add_errors(acc.errors)
              .compose_substitution(acc.substitution)
          end
      end

      def generalize(type)
        Generalization.generalize(type)
      end

      def unify(type1, type2)
        Unification.unify(type1, type2)
      end

      def instantiate(scheme)
        scheme.type
      end

      Env = Data.define(:bindings) do
        def initialize(bindings: {})
          super
        end

        def bind(key, value)
          bindings
            .merge(key => value)
            .then { with(bindings: it) }
        end
      end

      class VarGen
        def initialize
          @next_id = 1
        end

        def fresh
          "t#{@next_id}"
            .tap { @next_id += 1 }
        end
      end

      class FunctionBodyTypeMismatchError
        def initialize(node, expected, actual)
          @node = node
          @expected = expected
          @actual = actual
        end

        def message
          "There's a problem with the body of `#{@node.name}` definition: " ++
            "it returns #{@actual} but its signature says it should be #{@expected}"
        end
      end

      class InfixApplicationTypeMismatchError
        def initialize(node, expected, actual, side)
          @node = node
          @expected = expected
          @actual = actual
          @side = side == :left ? 'Left' : 'Right'
        end

        def message
          "#{@side} side of (#{@node.operator.value}) expects #{@expected} but found #{@actual}"
        end
      end

      class FunctionCallTypeMismatchError
        def initialize(node, expected, actual)
          @node = node
          @expected = expected
          @actual = actual
        end

        def message
          "Function call mismatch, expected #{@expected} but found #{@actual}"
        end
      end
    end
  end
end
