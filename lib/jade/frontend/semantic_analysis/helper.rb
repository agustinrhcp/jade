module Jade
  module Frontend
    module SemanticAnalysis
      module Helper
        def analyze_node(node, registry, scope, entry)
          SemanticAnalysis.send(:analyze_node, node, registry, scope, entry)
        end

        def bind(scope, symbol, entry)
          name = symbol.name
          if scope.lookup(name)
            Error::ShadowingError
              .new(entry.name, symbol.decl_span, name:)
              .then { Result[scope, [it]] }

          else
            Result[scope.bind(name, symbol), []]
          end
        end

        def lookup(scope, name, entry, span)
          if scope.lookup(name)
            Result[scope, []]

          else
            Error::UndefinedVariable
              .new(entry.name, span, var_ref: name)
              .then { Result[scope, [it]] }
          end
        end

        def analyze_many(nodes, registry, scope, entry)
          nodes.reduce(Result[scope, []]) do |acc, node|
            analyze_node(node, registry, acc.scope, entry) => Result[node_scope, node_errors]
            Result[node_scope, node_errors + acc.errors]
          end
        end

        def analyze_duplicate_fields(fields, entry)
          fields
            .group_by(&:key)
            .select { |_, v| v.size > 1 }
            .map do |k, v|
              first, *rest = v
              Error::DuplicateRecordField
                .new(entry.name, first.range, field_name: k, duplicate_spans: rest.map(&:range))
            end
        end

        def collect_vars(symbol, registry)
          case symbol
          in Symbol::TypeRef | Symbol::ValueRef
            registry
              .lookup(symbol)
              .then { collect_vars(it, registry) }

          in Symbol::Constructor(args:)
            args
              .flat_map { collect_vars(it, registry) }

          in Symbol::Variable
            [symbol]

          in Symbol::TypeApplication | Symbol::PartialApplication
            symbol
              .args
              .flat_map { collect_vars(it, registry) }

          in Symbol::FunctionType | Symbol::InterfaceFunction
            symbol
              .params
              .flat_map { collect_vars(it, registry) } +
                collect_vars(symbol.return_type, registry)

          in Symbol::RecordType(row_var:)
            row_var.nil? ? [] : [row_var]
          end
        end

        def validate_type_symbol(symbol, registry)
          case symbol
          in Symbol::Union(variants:, type_params:)
            variants.flat_map { validate_type_symbol(it, registry) } +
              type_params.flat_map { validate_type_symbol(it, registry) }

          in Symbol::Constructor(args:)
            args.flat_map { validate_type_symbol(it, registry) }

          in Symbol::TypeRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry) }

          in Symbol::ValueRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry) }

          in Symbol::Variable
            []

          in Symbol::PartialApplication(constructor:, args:)
            args.flat_map { validate_type_symbol(it, registry) }

          in Symbol::TypeApplication(constructor:, args:)
            constructor_symbol = registry.lookup(constructor)

            if constructor_symbol.type_params.size != args.size
              [Error::TypeArgsMismatch.new(
                  nil,
                  symbol.span,
                  type_name: constructor.name,
                  expected: constructor_symbol.type_params.size,
                  actual: args.size
              )]
            else
              []
            end + args.flat_map { validate_type_symbol(it, registry) }

          in Symbol::FunctionType | Symbol::InterfaceFunction | Symbol::InteropFunction
            validate_type_symbol(symbol.return_type, registry) +
              symbol.params.flat_map { validate_type_symbol(it, registry) }

          in Symbol::Function(params:, return_type:)
            validate_type_symbol(return_type, registry) +
              params.values.flat_map { validate_type_symbol(it, registry) }

          in Symbol::RecordType(fields:)
            fields.reduce([]) do |acc, (k, v)|
              acc + validate_type_symbol(v, registry)
            end

          in Symbol::Struct(type_params:, record_type:)
            validate_type_symbol(record_type, registry) +
              type_params.flat_map { validate_type_symbol(it, registry) }
          end
        end
      end
    end
  end
end
