module Jade
  module Frontend
    module SemanticAnalysis
      module Implementation
        extend self

        def analyze(node, registry, scope, entry)
          node => AST::Implementation(interface:, applied_type:, extends:, functions:)

          type_name  = applied_type.constructor.type
          make_error = ->(klass, **kw) { klass.new(entry.name, node.range, **kw) }

          unless entry.defined_types.key?(interface) || entry.defined_types.key?(type_name)
            make_error.(
              Error::OrphanImplementation,
              interface: entry.lookup_type(interface).qname,
              type:      entry.lookup_type(type_name).qname,
            ).then { return Result[scope, [it]] }
          end

          iface_sym = entry
            .lookup_type(interface)
            .to_ref
            .then { registry.lookup(it) }

          type_sym = entry
            .lookup_type(type_name)

          extends_errors = extends
            .flat_map do |iface_name|
              ext_sym = entry.lookup_type(iface_name)
              next [] if entry.implementations.key?([ext_sym.qname, type_sym.qname])

              make_error
                .(
                  Error::MissingExtendsImplementation,
                  interface:   ext_sym.qname,
                  type:        type_sym.qname,
                  required_by: iface_sym.qname,
                )
                .then { [it] }
            end

          cycle_errors =
            if extends_errors.empty? && cycle_in_extends?(iface_sym.qname, type_sym.qname, entry)
              make_error
                .(Error::CircularExtends, interface: iface_sym.qname, type: type_sym.qname)
                .then { [it] }
            else
              []
            end

          type_param_errors =
            case [parameterized_interface?(iface_sym), type_sym]
            in [true, { type_params: [] }]
              make_error
                .(Error::TypeParamRequired, interface: iface_sym.qname, type: type_sym.qname)
                .then { [it] }
            else
              []
            end

          Result[
            scope,
            fn_name_errors(functions, iface_sym, &make_error) +
              extends_errors +
              cycle_errors +
              type_param_errors,
          ]
        end

        private

        def parameterized_interface?(iface_sym)
          iface_sym.functions.any? { contains_partial_application?(it) }
        end

        def contains_partial_application?(sym)
          case sym
          in Symbol::PartialApplication
            true
          in { params:, return_type: }
            params.any? { contains_partial_application?(it) } || contains_partial_application?(return_type)
          else
            false
          end
        end

        def fn_name_errors(functions, iface_sym, &make_error)
          impl_names  = functions.map(&:name).to_set
          iface_names = iface_sym.functions.map(&:name).to_set
          unknown     = impl_names.difference(iface_names)

          if unknown.any?
            unknown.map { make_error.(Error::UnknownImplementationFunction, interface: iface_sym.qname, fn_name: it) }
          else
            iface_names
              .difference(impl_names)
              .map { make_error.(Error::MissingImplementationFunction, interface: iface_sym.qname, fn_name: it) }
          end
        end

        def cycle_in_extends?(interface_qname, type_qname, entry, visited: Set.new)
          key = [interface_qname, type_qname]
          return true if visited.include?(key)

          impl = entry.implementations[key]
          return false unless impl&.extends&.any?

          impl
            .extends
            .any? do
              cycle_in_extends?(
                it.qualified_name,
                type_qname,
                entry,
                visited: visited | [key],
              )
            end
        end
      end
    end
  end
end
