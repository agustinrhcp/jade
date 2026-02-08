module Jade
  module Frontend
    module SymbolResolution
      module FunctionDeclaration
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::FunctionDeclaration(name:, params:, return_type:, body:)

          fn_symbol = current_entry.lookup_value(name)

          params_w_sym = params.map do |param|
            param
              .type
              .with(symbol: fn_symbol.params[param.name])
              .then { param.with(type: it)}
          end

          ret_type_w_sym = return_type.with(symbol: fn_symbol.return_type)

          resolve_node(body, registry, current_entry)
            .map do
              node.with(
                body: it,
                symbol: fn_symbol.to_ref,
                params: params_w_sym,
                return_type: ret_type_w_sym,
              )
            end
        end
      end
    end
  end
end
