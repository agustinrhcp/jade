module Jade
  module Codegen
    module PortDecoder
      extend self

      PASS = "Jade::Decode::Decoder[Jade::Decode::Desc::Pass[]]"

      # `dictionaries` is the call site's constraint-attachment list; only
      # used when an arm is a Dict marker.
      def task_call(interop_fn, registry, dictionaries = [])
        [
          interop_fn.interop_module_name,
          ":#{interop_fn.name}",
          decoder(interop_fn, :ok, registry, dictionaries),
          decoder(interop_fn, :err, registry, dictionaries),
        ]
          .join(', ')
          .then { "Jade::Runtime.task_call(#{it})" }
      end

      private

      # Per-arm decoder. PortResolution stamps one of:
      # - :pass — Decode.Value or Never arm, no decoder needed
      # - Symbol::Implementation — concrete OR partial impl (with marker
      #   deps for free vars). We push a synthetic dict_env mapping the
      #   port's vars to the call-site dictionaries so generate_impl_dispatch
      #   can resolve markers uniformly.
      # - Symbol::InteropFunction::Dict — bare-var arm, decoder comes
      #   from the caller's threaded dictionary at the given constraint index
      def decoder(interop_fn, arm, registry, dictionaries)
        case interop_fn.decoders.fetch(arm)
        in Symbol::InteropFunction::PASS
          PASS

        in Symbol::Implementation => impl
          emit_impl_decoder(impl, interop_fn, dictionaries, registry)

        in Symbol::InteropFunction::Dict(constraint_index:)
          "#{FunctionCall.dispatch_value(dictionaries.fetch(constraint_index), registry)}[\"decoder\"]"
        end
      end

      def emit_impl_decoder(impl, interop_fn, dictionaries, registry)
        synthetic_env = build_synthetic_dict_env(impl, interop_fn, dictionaries, registry)

        Codegen
          .with_dict_env(synthetic_env, Frontend::TypeChecking::Substitution::EMPTY) {
            FunctionCall.generate_impl_dispatch(impl, registry).fetch('decoder')
          }
      end

      # Maps [iface, port_var_id] → ruby expression for the call-site dict.
      # For concrete impls (no markers) this is empty — generate_impl_dispatch
      # never reads dict_env. For partial impls, each marker dep's Type::Var
      # gets resolved to the dictionaries[i] corresponding to its name.
      def build_synthetic_dict_env(impl, interop_fn, dictionaries, registry)
        collect_marker_vars(impl).to_h do |iface, var|
          idx = interop_fn.constraints.index { |i, n| i == iface && n == var.name }
          [[iface, var.id], FunctionCall.dispatch_value(dictionaries.fetch(idx), registry)]
        end
      end

      def collect_marker_vars(impl, acc = [])
        impl.deps.each do |dep|
          case dep
          in Symbol::Implementation
            collect_marker_vars(dep, acc)

          in Type::Constraint(interface:, type: Type::Var => var)
            acc << [interface, var]
          end
        end
        acc.uniq { |iface, var| [iface, var.id] }
      end
    end
  end
end
