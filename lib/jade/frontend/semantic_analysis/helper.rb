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
              .then { Result[nil, [it], scope] }

          else
            Result[nil, [], scope.bind(name, symbol)]
          end
        end

        def lookup(scope, name, entry, span)
          if (decl = scope.lookup(name))
            Result[decl, [], scope]

          else
            Error::UndefinedVariable
              .new(entry.name, span, var_ref: name)
              .then { Result[nil, [it], scope] }
          end
        end

        # Threaded: child N analyzed with the scope produced by child N-1;
        # the returned scope is the last child's. Use when later siblings
        # depend on bindings introduced by earlier ones — body statements,
        # lambda/function params, sequential pattern bindings.
        def analyze_in_sequence(nodes, registry, scope, entry)
          nodes.reduce(Result[[], [], scope]) do |acc, node|
            r = analyze_node(node, registry, acc.scope, entry)
            Result[acc.node + [r.node], acc.errors + r.errors, r.scope]
          end
        end

        # Independent: every child analyzed with the input scope; the
        # returned scope is the input scope (no bindings leak). Use when
        # children don't see each other — record fields, list items,
        # function-call args, if/case branches.
        def analyze_in_parallel(nodes, registry, scope, entry)
          results = nodes.map { analyze_node(it, registry, scope, entry) }
          Result[results.map(&:node), results.flat_map(&:errors), scope]
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

          in Symbol::Alias(body:)
            # Aliases are transparent — vars are whatever the body has.
            # Skip if body unresolved (cycle / pre-deep-decl).
            body ? collect_vars(body, registry) : []
          end
        end

        def validate_type_symbol(symbol, registry, entry)
          case symbol
          in Symbol::Union(variants:, type_params:)
            variants.flat_map { validate_type_symbol(it, registry, entry) } +
              type_params.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::Constructor(args:)
            args.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::TypeRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry, entry) }

          in Symbol::ValueRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry, entry) }

          in Symbol::Variable
            []

          in Symbol::PartialApplication(constructor:, args:)
            args.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::TypeApplication(constructor:, args:)
            constructor_symbol = registry.lookup(constructor)

            if constructor_symbol.type_params.size != args.size
              [Error::TypeArgsMismatch.new(
                  entry.name,
                  symbol.span,
                  type_name: constructor.name,
                  expected: constructor_symbol.type_params.size,
                  actual: args.size
              )]
            else
              []
            end + args.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::FunctionType | Symbol::InterfaceFunction | Symbol::InteropFunction
            validate_type_symbol(symbol.return_type, registry, entry) +
              symbol.params.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::Function(params:, return_type:)
            validate_type_symbol(return_type, registry, entry) +
              params.values.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::RecordType(fields:)
            fields.reduce([]) do |acc, (k, v)|
              acc + validate_type_symbol(v, registry, entry)
            end

          in Symbol::Struct(type_params:, record_type:)
            validate_type_symbol(record_type, registry, entry) +
              type_params.flat_map { validate_type_symbol(it, registry, entry) }

          in Symbol::Alias(type_params:, body:)
            (body ? validate_type_symbol(body, registry, entry) : []) +
              type_params.flat_map { validate_type_symbol(it, registry, entry) }
          end
        end
      end
    end
  end
end
