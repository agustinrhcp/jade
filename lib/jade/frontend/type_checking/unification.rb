module Jade
  module Frontend
    module TypeChecking
      module Unification
        extend self

        def unify(type1, type2)
          case [type1, type2]
          in [Type::Constructor, Type::Constructor]
            type1 == type2 ?
              Ok[Substitution.new] :
              Err[UnificationError.new(type1, type2)]
          end
        end

        private

        class UnificationError
          attr_reader :expected, :actual

          def initialize(actual, expected)
            @actual = actual
            @expected = expected
          end

          def message
            "Cannot unify #{expected} with #{actual}"
          end
        end
      end
    end
  end
end
