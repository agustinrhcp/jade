require 'jade/frontend/type_checking/constraints'

module Jade
  module Codegen
    module Boundary
      extend self
      extend Helpers

      DECODABLE = 'Decode.Decodable'
      ENCODABLE = 'Encode.Encodable'

      VALUE_PASSTHROUGH_DECODER = 'Jade::Decode::Decoder[Jade::Decode::Desc::Pass[]]'
      VALUE_IDENTITY_ENCODER    = '->(v) { v }'
      NEVER_ENCODER             = '->(_) { fail "Never arm produced a value" }'

      def decoder_for(type, registry)
        case type
        in Type::Application(constructor: Type::Constructor(name:), args:)
          decode_app(name, args, registry)

        else
          nil
        end
      end

      def encoder_for(type, registry)
        case type
        in Type::Application(constructor: Type::Constructor(name:), args:)
          encode_app(name, args, registry)

        else
          nil
        end
      end

      def eligible?(fn_type, registry)
        args, return_type = Type.signature(fn_type)
        args.all? { decoder_for(it, registry) } &&
          return_eligible?(return_type, registry)
      end

      # Task in return position needs both arms encodable — the wrapper
      # discriminates the outcome rather than producing an encoded Task.
      # Everything else checks the type's own encoder directly.
      def return_eligible?(type, registry)
        case type
        in Type::Application(constructor: Type::Constructor(name: 'Task.Task'), args: [ok_t, err_t])
          !encoder_for(ok_t, registry).nil? && !encoder_for(err_t, registry).nil?

        else
          !encoder_for(type, registry).nil?
        end
      end

      def task_arms(task_type, registry)
        task_type => Type::Application(
          constructor: Type::Constructor(name: 'Task.Task'),
          args: [ok_t, err_t],
        )
        ok_enc  = encoder_for(ok_t, registry)
        err_enc = encoder_for(err_t, registry)
        [ok_enc, err_enc] if ok_enc && err_enc
      end

      private

      def decode_app(name, args, registry)
        case [name, args]
        in ['Basics.Int', []]    then intr_call('Decode.int')
        in ['Basics.Float', []]  then intr_call('Decode.float')
        in ['Basics.Bool', []]   then intr_call('Decode.bool')
        in ['String.String', []] then intr_call('Decode.string')
        in ['Decode.Value', []]  then VALUE_PASSTHROUGH_DECODER

        in ['List.List', [inner]]
          decoder_for(inner, registry)
            &.then { "#{intr('Decode.list')}.call(#{it})" }

        in ['Maybe.Maybe', [inner]]
          decoder_for(inner, registry)
            &.then { "#{intr('Decode.nullable')}.call(#{it})" }

        else
          decoder_dispatch(name, args, registry)
        end
      end

      def encode_app(name, args, registry)
        case [name, args]
        in ['Basics.Int', []]    then intr('Encode.int')
        in ['Basics.Float', []]  then intr('Encode.float')
        in ['Basics.Bool', []]   then intr('Encode.bool')
        in ['String.String', []] then intr('Encode.string')
        in ['Decode.Value', []]  then VALUE_IDENTITY_ENCODER

        # Never is uninhabited — the encoder can never be called. Treat as
        # eligible so Task(a, Never) boundaries work; raise loudly if the
        # impossible happens.
        in ['Basics.Never', []]  then NEVER_ENCODER

        in ['List.List', [inner]]
          encoder_for(inner, registry)
            &.then { "#{intr('Encode.list')}.curry[#{it}]" }

        in ['Maybe.Maybe', [inner]]
          encoder_for(inner, registry)
            &.then { "#{intr('Encode.nullable')}.curry[#{it}]" }

        # Task isn't a value-encodable type. `return_eligible?` and
        # `task_arms` handle Task in return position; here we just say
        # "no encoder" so other places that ask for an encoder on a Task
        # value get an honest nil.
        in ['Task.Task', _]
          nil

        else
          encoder_dispatch(name, args, registry)
        end
      end

      def intr(qname)
        "Jade::Runtime.intr(#{qname.inspect})"
      end

      def intr_call(qname)
        "#{intr(qname)}.call"
      end

      # Explicit impl returns a fn that produces a Decoder; derived impl is
      # already a Decoder.
      def decoder_dispatch(name, args, registry)
        if ref = impl_fn_ref(DECODABLE, name, 'decoder', registry)
          "#{ref}.call"
        else
          derived_dispatch(DECODABLE, name, args, registry)&.dig('decoder')
        end
      end

      # Encoder expressions evaluate to `a -> Value` directly — no `.call`
      # shim either way.
      def encoder_dispatch(name, args, registry)
        impl_fn_ref(ENCODABLE, name, 'encoder', registry) ||
          derived_dispatch(ENCODABLE, name, args, registry)&.dig('encoder')
      end

      def derived_dispatch(interface_qname, type_qname, args, registry)
        type       = Type.constructor(type_qname).apply(args)
        constraint = Type.constraint(interface_qname, type, nil)

        case Frontend::TypeChecking::Constraints.resolve(constraint, registry, nil)
        in Ok[impl] then Codegen::FunctionCall.generate_impl_dispatch(impl, registry)
        in Err      then nil
        end
      rescue NoMethodError, NoMatchingPatternError
        # Deriver assumes derivability (type-check-time invariant); boundary
        # synthesis may probe types whose deps fail — treat as ineligible.
        nil
      end

      def impl_fn_ref(interface_qname, type_qname, fn_name, registry)
        impl = registry.implementations[[interface_qname, type_qname]]
        return nil unless impl
        return nil unless impl.functions[fn_name].is_a?(Symbol::ValueRef)

        fn_sym = registry.lookup(impl.functions[fn_name])

        case fn_sym
        in Symbol::Function
          "#{to_qualified(fn_sym.module_name)}::Internal.#{fn_sym.name}"

        in Symbol::StdlibFunction(codegen:) if codegen.is_a?(String)
          codegen

        else
          nil
        end
      end
    end
  end
end
