require 'jade/frontend/type_checking/constraints'
require 'jade/frontend/type_checking/definition'
require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking/error'
require 'jade/frontend/type_checking/expected'
require 'jade/frontend/type_checking/inference'
require 'jade/frontend/type_checking/loader'
require 'jade/frontend/type_checking/result'
require 'jade/frontend/type_checking/state'
require 'jade/frontend/type_checking/substitution'
require 'jade/frontend/type_checking/unification'

require 'jade/frontend/type_checking/generalizer'

module Jade
  module Frontend
    module TypeChecking
      extend Inference::Helpers
      extend self

      def check(entry, registry)
        Loader
          .load(entry, registry)
          .then { check_node(entry.ast, registry, State.init(it, skip_constraints: true), Expected.infer(it.fresh)) }
          .then { Generalizer.generalize(it.first.env) }
          .then { check_node(entry.ast, registry, State.init(it), Expected.infer(it.fresh)) }
          .then { finalize(*it, registry) }
          .map { entry.with(env: it) }
      end

      def finalize(state, result, registry)
        state.env => { bindings:, entry_name: }

        errors = bindings
          .select do |k,v|
            # filter locals
            b_entry_name = k.split('.')[0..-2].join(',')
            b_entry_name == entry_name
          end
          .values
          .flat_map(&:constraints)
          .flat_map { Constraints.solve_at_finalize(it, registry, entry_name) }

        # TODO: impl declarations need their own finalization pass here.
        # Unresolved constraints from impl function bodies (e.g. Eq(a) from
        # `one.id == other.id` inside `impl Eq for Pepe(a)`) should be promoted
        # to impl-level requirements — making the impl an ImplementationTemplate
        # with those constraints — rather than being dropped silently.

        state
          .with(errors: state.errors + errors)
          .to_result
      end

      def check_repl(node, registry, env = Env.new)
        check_node(node, registry, env, Expected.infer(env.fresh))
          .to_result
      end

      def check_node(node, registry, state, expected_type)
        case node
        in AST::Body then Inference::Body
        in AST::CaseOf then Inference::CaseOf
        in AST::ConstructorReference then Inference::ConstructorReference
        in AST::FunctionCall then Inference::FunctionCall
        in AST::FunctionDeclaration then Inference::FunctionDeclaration
        in AST::Grouping then Inference::Grouping
        in AST::IfThenElse then Inference::IfThenElse
        in AST::Implementation then Inference::Implementation
        in AST::ImportDeclaration then Inference::ImportDeclaration
        in AST::InteropImportDeclaration then Inference::InteropImportDeclaration
        in AST::Lambda then Inference::Lambda
        in AST::List then Inference::List
        in AST::Literal | AST::CharLiteral then Inference::Literal
        in AST::Module then Inference::Module
        in AST::QualifiedAccess then Inference::QualifiedAccess
        in AST::RecordAccess then Inference::RecordAccess
        in AST::StructDeclaration then Inference::StructDeclaration
        in AST::RecordField then Inference::RecordField
        in AST::RecordLiteral then Inference::RecordLiteral
        in AST::RecordUpdate then Inference::RecordUpdate
        in AST::TypeDeclaration then Inference::TypeDeclaration
        in AST::Assign then Inference::Assign
        in AST::VariableReference then Inference::VariableReference
        end
          .infer(node, registry, state, expected_type)
      end
    end
  end
end
