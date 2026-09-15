module Jade
  module Frontend
    module TypeChecking
      module Requirements
        extend self

        def reconcile(entry, registry, state)
          pending = state
            .impl_requirements
            .to_h { |key, pairs| [key, pairs - declared_for(key, registry)] }
            .reject { |_, pairs| pairs.empty? }

          errors(entry, registry, pending)
            .then { return [entry, state.add_errors(it)] if it.any? }

          amended = amend_all(entry, pending)
          return [entry, state] if amended.equal?(entry)

          rebind(state.env, amended, registry)
            .then { recheck(entry, registry, it) }
            .then { |rechecked| [amended, rechecked] }
        end

        private

        def recheck(entry, registry, env)
          TypeChecking
            .check_node(entry.ast, registry, State.init(env), Expected.infer(env.fresh))
            .first
        end

        def rebind(env, entry, registry)
          entry
            .defined_values
            .each_value
            .select { it.is_a?(Symbol::InterfaceFunction) && it.constraints.any? }
            .reduce(env) do |acc, sym|
              Type
                .from_symbol(sym, registry, acc.var_gen)
                .then { Inference::Helpers.generalize(acc, *it) }
                .then { acc.bind(sym.qualified_name, it) }
            end
        end

        def declared_for((interface, fn_name), registry)
          Symbol
            .type_ref_from_qualified_name(interface)
            .then { registry.lookup(it) }
            .then { it.is_a?(Symbol::Interface) ? it.functions : [] }
            .find { it.name == fn_name }
            &.constraints || []
        end

        def errors(entry, registry, pending)
          pending.flat_map do |(interface, fn_name), constraints|
            declared = declared_for([interface, fn_name], registry)
            next [] if declared.empty? && local?(entry, interface)

            constraints.map do |iface, var|
              error_for(entry, interface, fn_name, "#{iface} #{var}", declared)
            end
          end
        end

        def local?(entry, interface)
          entry.defined_types.key?(interface.split('.').last)
        end

        def error_for(entry, interface, fn_name, constraint, declared)
          return cross_module_error(entry, interface, fn_name, constraint) if declared.empty?

          Error::UndeclaredRequirement.new(
            entry.name,
            nil,
            interface:,
            fn_name:,
            constraint:,
            declared: declared.map { |iface, var| "#{iface} #{var}" }.join(', '),
          )
        end

        def cross_module_error(entry, interface, fn_name, constraint)
          Error::CrossModuleRequirement.new(
            entry.name,
            nil,
            interface:,
            fn_name:,
            constraint:,
          )
        end

        def amend_all(entry, pending)
          pending.reduce(entry) do |acc, ((interface, fn_name), constraints)|
            amend_method(acc, interface, fn_name, constraints)
          end
        end

        def amend_method(entry, interface_qname, fn_name, constraints)
          symbol = entry.defined_types[interface_qname.split('.').last]
          return entry unless symbol.is_a?(Symbol::Interface)

          symbol
            .functions
            .map { it.name == fn_name ? with_constraints(it, constraints) : it }
            .then { symbol.with(functions: it) }
            .then { |iface| iface.functions.reduce(entry.define(iface)) { |acc, fn| acc.define(fn) } }
        end

        def with_constraints(fn, constraints)
          fn.with(constraints: (fn.constraints + constraints).uniq)
        end
      end
    end
  end
end
