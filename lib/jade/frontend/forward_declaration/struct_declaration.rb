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

          record_type_symbol = figure_out_type(entry, record_type)

          constructor_fn_symbol = Symbol.function(
            name,
            record_type_symbol.fields,
            symbol.to_ref,
          )

          record_type_symbol
            .then { symbol.with(record_type: it) }
            .then { entry.define(it) }
            .then { it.define(constructor_fn_symbol) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
