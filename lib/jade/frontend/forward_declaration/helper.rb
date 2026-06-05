module Jade
  module Frontend
    module ForwardDeclaration
      module Helper
        def shallow_declare_node(ast, registry, entry)
          ForwardDeclaration.shallow_declare_node(ast, registry, entry)
        end

        def deep_declare_node(ast, entry, registry)
          ForwardDeclaration.deep_declare_node(ast, entry, registry)
        end

        def figure_out_type(entry, node)
          case node
          in AST::TypeVar(type:)
            Ok[Symbol.var(type, node.range)]

          in AST::TypeName(type:)
            require_type(entry, type, node.range)
              .map { Symbol.type_application(it.to_ref, []) }

          in AST::TypeApplication(constructor:, args:)
            constructor_r =
              case constructor
              in AST::TypeName
                require_type(entry, constructor.type, constructor.range)

              in AST::QualifiedTypeName(path:)
                *module_parts, type_name = path
                require_qualified_type(entry, module_parts.join('.'), type_name, constructor.range)
              end

            args
              .map { figure_out_type(entry, it) }
              .then { Results.sequence(it) }
              .and_then { |resolved_args| constructor_r.map { Symbol.type_application(it.to_ref, resolved_args, node.range) } }

          in AST::TypeFunction(params:, return_type:)
            params
              .map { figure_out_type(entry, it) }
              .then { Results.sequence(it) }
              .and_then { |resolved_params| figure_out_type(entry, return_type).map { Symbol.function_type(resolved_params, it) } }

          in AST::TypeTuple(items:) if items.length > Error::TupleArityOverflow::MAX_ARITY
            Err[Error::TupleArityOverflow.new(entry&.name, node.range, arity: items.length)]

          in AST::TypeTuple(items:)
            type_name = Stdlib::Tuple.constructor_by_arity(items.length)

            items
              .map { figure_out_type(entry, it) }
              .then { Results.sequence(it) }
              .map { Symbol.type_application(Symbol.type_ref(*type_name.split('.')), it, node.range) }

          in AST::TypeRecord(fields:, row_var:)
            row = row_var&.then { |row| Symbol.var(row.name, row.range) }

            fields
              .map { |k, v| figure_out_type(entry, v).map { [k, it] } }
              .then { Results.sequence(it) }
              .map { Symbol.record_type(it.to_h, row) }
          end
        end

        private

        def require_type(entry, name, span)
          entry.lookup_type(name)
            &.then { Ok[it] } ||
            Err[Error::TypeNotFound.new(
              entry.name, span, name:,
              candidates: entry.types.keys,
            )]
        end

        def require_qualified_type(entry, module_path, type_name, span)
          entry.lookup_qualified_type(module_path, type_name)
            &.then { Ok[it] } ||
            Err[Error::TypeNotFound.new(entry.name, span, name: "#{module_path}.#{type_name}")]
        end

        def to_declaration_result(entry, r)
          case r
          in Ok[sym] then Result[sym, []]
          in Err[e]  then Result[entry, [e]]
          end
        end
      end
    end
  end
end
