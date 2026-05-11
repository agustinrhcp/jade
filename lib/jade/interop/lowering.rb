require 'jade/interop/lowering/error'

module Jade
  module Interop
    module Lowering
      extend self

      # Walks a port's return type and returns the kinds of types that can
      # never have a Decodable instance: bare type variables and function
      # types. Everything else is permitted at this phase; the real
      # decodability check happens at codegen via Constraints.resolve.
      def validate(symbol, registry, entry)
        case symbol
        in Symbol::Variable(name:)
          [TypeParamError.new(name)]

        in Symbol::Function(name:)
          [FunctionError.new(name)]

        in Symbol::FunctionType
          [FunctionError.new('inline function type')]

        in Symbol::TypeApplication(args:)
          args.flat_map { validate(it, registry, entry) }

        in Symbol::RecordType(fields:)
          fields.values.flat_map { validate(it, registry, entry) }

        in Symbol::Struct(record_type:)
          validate(record_type, registry, entry)

        in Symbol::TypeRef
          lookup_type(symbol, registry, entry)
            &.then { validate(it, registry, entry) } || []

        else
          []
        end
      end

      private

      def lookup_type(ref, registry, entry)
        if ref.module_name == entry.name
          entry.lookup_type(ref.name)
        else
          registry.lookup(ref)
        end
      end
    end
  end
end
