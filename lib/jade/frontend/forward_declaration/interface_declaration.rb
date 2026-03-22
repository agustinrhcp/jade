module Jade
  module Frontend
    module ForwardDeclaration
      module InterfaceDeclaration
        extend self
        extend Helper

        def shallow(node, _registry, entry)
          node => AST::InterfaceDeclaration(name:, type_param:, functions:)

          interface_ref = Symbol.type_ref(entry.name, name)
          type_var = Symbol.var(type_param.name, type_param.range)

          functions
            .map do |fn|
              Symbol
                .interface_function(fn.name, interface_ref, [], nil, fn.range)
            end
            .then do |fn_symbols|
              Symbol.interface(name, type_var, fn_symbols, {}, node.range)
                .then { entry.define(it) }
                .then { fn_symbols.reduce(it) { |acc, fn| acc.define(fn) } }
            end
            .then { Result[it, []] }
        end

        def deep(node, entry, _registry)
          node => AST::InterfaceDeclaration(name:, functions:)

          symbol = entry.lookup_type(name)
          interface_ref = symbol.to_ref

          functions
            .map { build_interface_function(entry, interface_ref, it) }
            .then { Results.sequence(it) }
            .map do |fn_symbols|
              fn_symbols
                .reduce(entry) { |acc, fn| acc.define(fn) }
                .then { it.define(symbol.with(functions: fn_symbols)) }
            end
            .then { to_declaration_result(entry, it) }
        end

        private

        def build_interface_function(entry, interface_ref, fn_decl)
          fn_decl => AST::InterfaceFunctionDecl(name:, type:, range:)

          figure_out_type(entry, type)
            .map do |type_symbol|
              params, return_type =
                case type_symbol
                in Symbol::FunctionType(params:, return_type:)
                  [params, return_type]
                else
                  [[], type_symbol]
                end

              Symbol
                .interface_function(name, interface_ref, params, return_type, range)
            end
        end
      end
    end
  end
end
