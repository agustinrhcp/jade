module Jade
  module Frontend
    module SemanticAnalysis
      module InterfaceDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::InterfaceDeclaration(symbol:)

          interface = registry.lookup(symbol)

          (
            interface
              .functions
              .flat_map { validate_type_symbol(it, registry) } +
                validate_type_param_used(interface, registry, entry)
          )
            .then { Result[scope, it] }
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
              entry&.name,
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
