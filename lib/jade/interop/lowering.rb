require 'jade/interop/lowering/error'

module Jade
  module Interop
    module Lowering
      extend self

      Result = Data.define(:lowered_type, :errors) do
        def self.good(type)
          self.new(type, [])
        end

        def self.bad(error)
          self.new(nil, [error])
        end

        def wrap(type)
          map { [type, it] }
        end

        def map
          with(lowered_type: yield(lowered_type))
        end

        def errored(more_errors)
          with(errors: errors + more_errors)
        end
      end

      def lower_symbol(symbol, registry, entry)
        case symbol
        in Symbol::TypeApplication(constructor: Symbol::TypeRef('Basics', 'Never'))
          Result.good('never')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef('Basics', 'Int'))
          Result.good('int')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef('Basics', 'Float'))
          Result.good('float')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef('Basics', 'Bool'))
          Result.good('bool')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef('String', 'String'))
          Result.good('string')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['Maybe', 'Maybe'], args: [arg])
          lower_symbol(arg, registry, entry)
            .wrap('maybe')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['Maybe', 'Maybe'], args:)
          # TODO: Is malformed, it will fail later
          Result.good('maybe')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['List', 'List'], args: [arg])
          lower_symbol(arg, registry, entry)
            .wrap('list')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['List', 'List'], args:)
          # TODO: Is malformed, it will fail later
          Result.good('list')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['Decode', 'Value'], args: [])
          Result.good('decode_value')

        in Symbol::TypeApplication(constructor: Symbol::TypeRef['Task', 'Task'], args: [ok_arg, err_arg])
          ok  = lower_symbol(ok_arg,  registry, entry)
          err = lower_symbol(err_arg, registry, entry)
          Result
            .good(['task', ok.lowered_type, err.lowered_type])
            .errored(ok.errors + err.errors)

        in Symbol::RecordType(fields:)
          fields
            .reduce(Result.good({})) do |acc, (key, val)|
              lower_symbol(val, registry, entry)
                .map { acc.lowered_type.merge(key => it) }
                .errored(acc.errors)
            end

        in Symbol::Struct(record_type:)
          lower_symbol(record_type, registry, entry)

        in Symbol::TypeApplication(constructor: Symbol::TypeRef => ref, args: [])
          resolved = lookup_type(ref, registry, entry)
          if resolved.is_a?(Symbol::Struct)
            lower_symbol(resolved, registry, entry)
          else
            Result.bad(UnionError.new(ref.name))
          end

        in Symbol::TypeRef
          lookup_type(symbol, registry, entry)
            .then { lower_symbol(it, registry, entry) }

        in Symbol::Variable(name:)
          Result.bad(TypeParamError.new(name))

        in Symbol::Function(name:)
          Result.bad(FunctionError.new(name))

        in Symbol::TypeApplication(constructor:)
          Result.bad(UnionError.new(constructor.name))

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
