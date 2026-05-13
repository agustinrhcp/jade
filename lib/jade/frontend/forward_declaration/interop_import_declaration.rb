module Jade
  module Frontend
    module ForwardDeclaration
      module InteropImportDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::InteropImportDeclaration(functions:)

          functions
            .reduce(entry) do |acc, fn|
              Symbol
                .predeclared_interop_function(fn.name)
                .then { entry.define(it) }
            end
            .then { Result[it, []] }
        end

        def deep(node, entry, registry)
          node => AST::InteropImportDeclaration(module: mod_name, functions:)

          functions
            .reduce([entry, []]) do |(acc, errors), fn|
              case figure_out_type(entry, fn.type)
              in Err[e]
                [acc, errors + [e]]

              in Ok[type_sym]
                wrap_in_fn_type(type_sym)
                  .then { fn_type_to_interop(mod_name, fn, it, entry, registry) }
                  .then { |(sym, interop_errors)| [acc.define(sym), errors + interop_errors] }
              end
            end
            .then { Result[*it] }
        end

        private

        def wrap_in_fn_type(symbol)
          case symbol
          in Symbol::Function | Symbol::FunctionType
            symbol
          else
            Symbol.function_type([], symbol)
          end
        end

        def fn_type_to_interop(interop_mod_name, function_node, symbol, entry, registry)
          lifted_errors = Interop::Lowering
            .validate(symbol.return_type, registry, entry)
            .map { Error::TypeNotLowerable.new(entry, function_node.range, message: it.message) }

          Symbol
            .interop_function(
              function_node.name,
              symbol.params,
              symbol.return_type,
              interop_mod_name.name,
              constraints: implicit_decodable_constraints(symbol.return_type),
            )
            .then { [it, lifted_errors] }
        end

        # Free type variables anywhere under the return TypeApplication's
        # arms get an implicit Decodable constraint. Ports resolve these
        # to dict markers (bare arms) or partial impls (nested arms) in
        # port_resolution.rb. Non-port shapes yield [].
        def implicit_decodable_constraints(return_type)
          case return_type
          in Symbol::TypeApplication(args:)
            args
              .flat_map { collect_var_names(it) }
              .uniq
              .map { ['Decode.Decodable', it] }
          else
            []
          end
        end

        def collect_var_names(type_sym)
          case type_sym
          in Symbol::Variable(name:)
            [name]

          in Symbol::TypeApplication(args:)
            args.flat_map { collect_var_names(it) }

          in Symbol::RecordType(fields:)
            fields.values.flat_map { collect_var_names(it) }

          else
            []
          end
        end
      end
    end
  end
end
