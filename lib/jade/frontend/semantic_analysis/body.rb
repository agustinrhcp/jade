module Jade
  module Frontend
    module SemanticAnalysis
      module Body
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Body(expressions:)

          duplicate_errors = expressions
            .select { it.is_a?(AST::FunctionDeclaration) }
            .group_by(&:name)
            .filter_map do |name, decls|
              next nil if decls.size < 2

              first, *rest = decls
              Error::DuplicateFunctionDeclaration.new(
                entry.name,
                first.range,
                name,
                duplicate_spans: rest.map(&:range),
              )
            end

          analyze_in_sequence(expressions, registry, scope, entry)
            .add_errors(duplicate_errors + duplicate_implementation_errors(expressions, entry))
            .map_node { node.with(expressions: it) }
        end

        private

        def duplicate_implementation_errors(expressions, entry)
          expressions
            .select { it.is_a?(AST::Implementation) }
            .group_by { implementation_key(it, entry) }
            .reject { |key, impls| key.nil? || impls.size < 2 }
            .flat_map do |(interface, type), (first, *rest)|
              rest.map do |dup|
                Error::DuplicateImplementation.new(
                  entry.name,
                  dup.range,
                  interface:,
                  type:,
                  first_span: first.range,
                  parameterized: dup.applied_type.args.any?,
                )
              end
            end
        end

        def implementation_key(node, entry)
          interface = entry.lookup_type(node.interface)
          type = lookup_applied_type(node.applied_type, entry)

          [interface.qname, type.qname] if interface && type
        end
      end
    end
  end
end
