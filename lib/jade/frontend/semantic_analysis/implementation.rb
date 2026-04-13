module Jade
  module Frontend
    module SemanticAnalysis
      module Implementation
        extend self

        def analyze(node, registry, scope, entry)
          node => AST::Implementation(interface:, constructor:, functions:)

          owns_interface = entry.defined_types.key?(interface)
          owns_type      = entry.defined_types.key?(constructor)

          unless owns_interface || owns_type
            Error::OrphanImplementation
              .new(
                entry.name, node.range,
                interface: entry.lookup_type(interface).qualified_name,
                type:      entry.lookup_type(constructor).qualified_name,
              )
              .then { return Result[scope, [it]] }
          end

          interface_ref = entry.lookup_type(interface).to_ref
          iface_sym     = registry.lookup(interface_ref)
          iface_qname   = interface_ref.qualified_name

          impl_names  = functions.map(&:name).to_set
          iface_names = iface_sym.functions.map(&:name).to_set

          unknown = impl_names.difference(iface_names)

          errors =
            if unknown.any?
              unknown
                .map do
                  Error::UnknownImplementationFunction
                    .new(entry.name, node.range, interface: iface_qname, fn_name: it)
                end
            else
              iface_names
                .difference(impl_names)
                .map do
                  Error::MissingImplementationFunction
                    .new(entry.name, node.range, interface: iface_qname, fn_name: it)
                end
            end

          Result[scope, errors]
        end
      end
    end
  end
end
