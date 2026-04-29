module Jade
  module Frontend
    module ForwardDeclaration
      module FunctionDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::FunctionDeclaration(name:)

          Symbol
            .predeclared_function(name)
            .then { entry.define(it) }
            .then { Result[it, []] }
        end

        def deep(node, entry, _)
          node => AST::FunctionDeclaration(name:, params:, return_type:)

          params
            .map { |param| param.type.then { figure_out_type(entry, it) }.map { [param.name, it] } }
            .then { Results.sequence(it) }
            .map(&:to_h)
            .and_then { |params_types| figure_out_type(entry, return_type).map { [params_types, it] } }
            .map { |params_types, return_type_type| Symbol.function(name, params_types, return_type_type) }
            .map { entry.define(it) }
            .then { to_declaration_result(entry, it) }
        end
      end
    end
  end
end
