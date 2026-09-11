module Jade
  module Frontend
    module SemanticAnalysis
      module ModuleNode
        extend self
        extend Helper

        DECLARATIONS = [
          AST::FunctionDeclaration,
          AST::TypeDeclaration,
          AST::TypeAliasDeclaration,
          AST::StructDeclaration,
          AST::InterfaceDeclaration,
          AST::Implementation,
          AST::ImportDeclaration,
          AST::InteropImportDeclaration,
        ].freeze

        def analyze(node, registry, scope, entry)
          node => AST::Module(body:, exposing:)

          exposing_errors = case exposing
          in AST::ExposeNone
            [Error::MissingExposingClause.new(entry.name, 0..0)]
          else
            []
          end

          Result
            .combine(node, scope:,
              body: analyze_node(body, registry, scope, entry),
            )
            .add_errors(exposing_errors + statement_errors(body, entry))
        end

        private

        def statement_errors(body, entry)
          body
            .expressions
            .reject { |node| DECLARATIONS.any? { node.is_a?(it) } }
            .map { Error::TopLevelStatement.new(entry.name, it.range) }
        end
      end
    end
  end
end
