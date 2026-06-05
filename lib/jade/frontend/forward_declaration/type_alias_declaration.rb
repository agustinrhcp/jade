module Jade
  module Frontend
    module ForwardDeclaration
      module TypeAliasDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::TypeAliasDeclaration(name:, type_params:)

          type_params
            .map { Symbol.var(it.name, it.range) }
            .then { Symbol.predeclared_alias(name, it, node.range) }
            .then { entry.define(it) }
            .then { Result[it, []] }
        end

        def deep(node, entry, _)
          node => AST::TypeAliasDeclaration(name:, body_type:)

          symbol = entry.lookup_type(name)

          figure_out_type(entry, body_type)
            .map do |body_symbol|
              entry.define(symbol.with(body: body_symbol))
            end
            .then { to_declaration_result(entry, it) }
        end
      end
    end
  end
end
