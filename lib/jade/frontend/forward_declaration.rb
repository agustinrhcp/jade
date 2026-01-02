module Jade
  module Frontend
    module ForwardDeclaration
      extend self

      def declare(ast, registry, entry)
        shallow(ast, registry, entry)
          .then { deep(ast, it) }
      end

      def declare_entry(entry, registry)
        declare(entry.ast, registry, entry)
      end

      private

      def shallow(ast, registry, entry)
        case ast
        in AST::Module(body:)
          shallow(body, registry, entry)

        in AST::ImportDeclaration(module_name:)
          registry.get(module_name) => { types:, values: }

          (types.values + values.values)
            .map(&:to_ref)
            .reduce(entry) do |acc, sym|
              acc.add_imported_symbol(sym)
            end

        in AST::FunctionDeclaration(name:)
          Symbol.predeclared_function(name)
            .then { entry.add_symbol(it) }

        in AST::Body(expressions:)
          expressions.reduce(entry) { |acc, expr| shallow(expr, registry, acc) }

        in AST::TypeDeclaration(name:, type_params:)
          ast.type_params.map(&:name).map { Symbol.var(it) }
            .then { Symbol.union(name, it) }
            .then { entry.add_symbol(it) }

        else
          entry
        end
      end

      # TODO: [ForwardDeclaration:HandleErrors]
      def deep(ast, entry)
        case ast
        in AST::Module(body:)
          deep(body, entry)

        in AST::ImportDeclaration
          entry

        in AST::FunctionDeclaration(name:, params:, return_type:)
          params_types = params
            .map do |param|
              param => { type: }

              [param.name, figure_out_type(entry, type)]
            end
            .to_h

          return_type_type = figure_out_type(entry, return_type)

          Symbol
            .function(name, params_types, return_type_type)
            .then { entry.add_symbol(it) }


        in AST::TypeDeclaration(name:, variants:)
          symbol = entry.lookup_type(name)

          variant_symbols = variants
            .map do |var|
              var
                .args
                .map { |arg| figure_out_type(entry, arg) }
                .then { Symbol.variant(var.name, it, symbol.to_ref) }
            end

          variant_symbols
            .reduce(entry) { |acc_entry, sym| acc_entry.add_symbol(sym) }
            .then { it.add_symbol(symbol.with(variants: variant_symbols.map(&:to_ref))) }

        in AST::Body(expressions:)
          expressions.reduce(entry) { |acc, expr| deep(expr, acc) }

        else
          entry
        end
      end

      def figure_out_type(entry, type)
        case type
        in AST::TypeVar(type:)
          Symbol.var(type)

        in AST::TypeName(type:)
          entry.lookup_type(type)

        in AST::TypeApplication(constructor:)
          entry.lookup_type(constructor.type)
        end
      end
    end
  end
end
