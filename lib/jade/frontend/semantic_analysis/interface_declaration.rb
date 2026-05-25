module Jade
  module Frontend
    module SemanticAnalysis
      module InterfaceDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::InterfaceDeclaration(name:)

          symbol_ref = entry.lookup_type(name).to_ref
          interface = registry.lookup(symbol_ref)

          Result
            .init(node.with(symbol: symbol_ref), scope)
            .add_errors(
              interface.functions.flat_map { validate_type_symbol(it, registry, entry) } +
                validate_type_param_used(interface, registry, entry),
            )
        end

        private

        def validate_type_param_used(interface, registry, entry)
          used_names = interface
            .functions
            .flat_map { collect_vars(it, registry) }
            .map(&:name)
            .to_set

          return [] if used_names.include?(interface.type_param.name)

          [
            Error::UnusedInterfaceTypeParam.new(
              entry.name,
              interface.decl_span,
              interface: interface.name,
              type_param: interface.type_param.name,
            )
          ]
        end
      end
    end
  end
end
