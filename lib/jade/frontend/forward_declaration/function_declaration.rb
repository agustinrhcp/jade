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

          params_types = params
            .map do |param|
              param => { type: }

              [param.name, figure_out_type(entry, type)]
            end
            .to_h

          return_type_type = figure_out_type(entry, return_type)

          Symbol
            .function(name, params_types, return_type_type)
            .then { entry.define(it) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
