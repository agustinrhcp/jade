module Jade
  module Frontend
    module ForwardDeclaration
      module Implementation
        extend self
        extend Helper

        def shallow(_node, _registry, entry)
          Result[entry, []]
        end

        def deep(node, entry, _registry)
          node => AST::Implementation(interface:, applied_type:, extends:, functions:)

          interface_ref  = entry.lookup_type(interface).to_ref
          type_ref       = figure_out_type(entry, applied_type).constructor
          type_name      = applied_type.constructor.type

          extends_errors = extends
            .filter_map do |iface_name|
              next if entry.lookup_type(iface_name)

              Error::UnknownExtendsInterface
                .new(
                  entry.name,
                  node.range,
                  interface: iface_name,
                ) 
            end

          return Result[entry, extends_errors] if extends_errors.any?

          extends_refs = extends.map { entry.lookup_type(it).to_ref }

          entry_with_fns, fn_map = functions
            .reduce([entry, {}]) do |(acc_entry, acc_map), impl_fn|
              ImplementationFunction
                .declare(impl_fn, acc_entry, interface, type_name)
                .then { |e, ref| [e, acc_map.merge(impl_fn.name => ref)] }
            end

          Symbol
            .implementation(
              interface_ref,
              type_ref,
              [],
              [],
              fn_map,
              [],
              node.range,
              extends: extends_refs,
            )
            .then { entry_with_fns.define(it) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
