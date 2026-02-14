require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking/substitution'
require 'jade/frontend/type_checking/unification'
require 'jade/frontend/type_checking/generalization'
require 'jade/frontend/type_checking/instantiation'
require 'jade/frontend/type_checking/inference'
require 'jade/frontend/type_checking/error'

module Jade
  module Frontend
    module TypeChecking
      extend Inference::Helpers
      extend self

      Expected = Data.define(:type, :authoritative) do
        def auth?
          authoritative == true
        end

        def self.auth(type)
          self[type, true]
        end

        def self.non_auth(var_gen)
          self[var_gen.fresh, false]
        end
      end

      Result = Data.define(:type, :substitution, :env, :errors) do
        def and_unify(actual, &block)
          fail if actual.is_a?(Expected)
          case Unification.unify(type, actual)
          in Ok(sub)
            compose_substitution(sub)
              .apply
          in Err(error)
            fail "block is mandatory" unless block

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

      def check(entry, registry)
        var_gen = VarGen.new

        Env
          .load(entry, registry, var_gen)
          .then { check_node(entry.ast, registry, it, var_gen, Expected.non_auth(var_gen)) }
          .to_result
          .map { entry }
      end

      def check_repl(node, registry, env = Env.new, var_gen = VarGen.new)
        check_node(node, registry, env, var_gen, Expected.non_auth(var_gen.fresh))
          .to_result
      end

      def check_node(node, registry, env, var_gen, expected_type)
        case node
        in AST::Body then Inference::Body
        in AST::CaseOf then Inference::CaseOf
        in AST::ConstructorReference then Inference::ConstructorReference
        in AST::FunctionCall then Inference::FunctionCall
        in AST::FunctionDeclaration then Inference::FunctionDeclaration
        in AST::Grouping then Inference::Grouping
        in AST::IfThenElse then Inference::IfThenElse
        in AST::ImportDeclaration then Inference::ImportDeclaration
        in AST::InfixApplication then Inference::InfixApplication
        in AST::InteropImportDeclaration then Inference::InteropImportDeclaration
        in AST::Lambda then Inference::Lambda
        in AST::List then Inference::List
        in AST::Literal then Inference::Literal
        in AST::Module then Inference::Module
        in AST::QualifiedAccess then Inference::QualifiedAccess
        in AST::RecordAccess then Inference::RecordAccess
        in AST::StructDeclaration then Inference::StructDeclaration
        in AST::RecordField then Inference::RecordField
        in AST::RecordLiteral then Inference::RecordLiteral
        in AST::RecordUpdate then Inference::RecordUpdate
        in AST::TypeDeclaration then Inference::TypeDeclaration
        in AST::VariableBinding then Inference::VariableBinding
        in AST::VariableReference then Inference::VariableReference
        end
          .infer(node, registry, env, var_gen, expected_type)
      end

      private


      class VarGen
        def initialize
          @next_id = 1
        end

        def fresh_id
          "t#{@next_id}"
            .tap { @next_id += 1 }
        end

        def fresh(name = nil)
          fresh_id
            .then { Type.var(it, name) }
        end

        def next(name)
          "#{name}#{@next_id}"
            .tap { @next_id += 1 }
            .then { Type.var(it, name) }
        end
      end
    end
  end
end
