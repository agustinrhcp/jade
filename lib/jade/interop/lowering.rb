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

      def lower_symbol(symbol, registry)
        case symbol
        in Symbol::TypeApplication(Symbol::TypeRef('Basics', 'Int'), [])
          Result.good('int')

        in Symbol::TypeApplication(Symbol::TypeRef('Basics', 'Float'), [])
          Result.good('float')

        in Symbol::TypeApplication(Symbol::TypeRef('Basics', 'Bool'), [])
          Result.good('bool')

        in Symbol::TypeApplication(Symbol::TypeRef('String', 'String'), [])
          Result.good('string')

        in Symbol::TypeApplication(Symbol::TypeRef['Maybe', 'Maybe'], [arg])
          lower_symbol(arg, registry)
            .wrap('maybe')

        in Symbol::TypeApplication(Symbol::TypeRef['List', 'List'], [arg])
          lower_symbol(arg, registry)
            .wrap('list')

        in Symbol::RecordType(fields:)
          fields
            .reduce(Result.good({})) do |acc, (key, val)|
              lower_symbol(val, registry)
                .map { acc.lowered_type.merge(key => it) }
                .errored(acc.errors)
            end

        in Symbol::TypeRef
          registry
            .lookup(symbol)
            .then { lower_symbol(it, registry) }

        in Symbol::Variable(name:)
          Result.bad(TypeParamError.new(name))

        in Symbol::Function(name:)
          Result.bad(FunctionError.new(name))

        in Symbol::TypeApplication(constructor:)
          Result.bad(UnionError.new(constructor.name))

        end
      end
    end
  end
end
