module Jade
  module Codegen
    module PortDecoder
      extend self

      PASS = "Jade::Decode::Decoder[Jade::Decode::Desc::Pass[]]"

      # Emits the full `Jade::Runtime.task_call(...)` callee for a port. Both
      # codegen sites that reach an InteropFunction (VariableReference and
      # FunctionCall) come through here.
      def task_call(interop_fn, registry)
        [
          interop_fn.interop_module_name,
          ":#{interop_fn.name}",
          decoder(interop_fn, :ok, registry),
          decoder(interop_fn, :err, registry),
        ]
          .join(', ')
          .then { "Jade::Runtime.task_call(#{it})" }
      end

      private

      # Looks up the pre-resolved Decodable for one arm. PortResolution stamps
      # either a Symbol::Implementation or the :pass sentinel during
      # type-checking; we just translate it to Ruby here.
      def decoder(interop_fn, arm, registry)
        case interop_fn.decoders.fetch(arm)
        in Symbol::InteropFunction::PASS
          PASS

        in Symbol::Implementation => impl
          FunctionCall
            .generate_impl_dispatch(impl, registry)
            .fetch('decoder')
        end
      end
    end
  end
end
