module Jade
  module Frontend
    module ForwardDeclaration
      module StructDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::StructDeclaration(name:, type_params:)

          type_params
            .map { Symbol.var(it.name, it.range) }
            .then { Symbol.predeclared_struct(name, it, node.range) }
            .then { entry.define(it) }
            .then { Result[it, []] }
        end

        def deep(node, entry, _)
          node => AST::StructDeclaration(name:, record_type:)

          symbol = entry.lookup_type(name)

          figure_out_type(entry, record_type)
            .map do |record_type_symbol|
              constructor_fn_symbol = Symbol.constructor(
                name,
                record_type_symbol.fields.values,
                symbol.to_ref,
                nil,
              )

              record_type_symbol
                .then { symbol.with(record_type: it) }
                .then { entry.define(it) }
                .then { it.define(constructor_fn_symbol) }
            end
            .then { to_declaration_result(entry, it) }
        end
      end
    end
  end
end
