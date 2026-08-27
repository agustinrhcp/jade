module Jade
  module Frontend
    module TypeChecking
      module Error
        # Inference ids (`t8894`) are counters: they change between
        # compiles, and two occurrences of one variable look unrelated
        # unless you notice the digits match. Read out as `a`, `b`, `c`;
        # the ids themselves stay internal.
        module Display
          extend self

          LETTERS = ('a'..'z').to_a.freeze

          Naming = Data.define(:substitution) do
            def [](type)
              substitution.apply(type).to_s
            end
          end

          # Every type in one message at once, so a variable is the same
          # letter on both sides of it.
          def naming(*types)
            types
              .flat_map(&:unbound_vars)
              .uniq(&:id)
              .select { it.name.nil? }
              .each_with_index
              .to_h { |var, i| [var.id, Type.var(var.id, letter(i))] }
              .then { Naming[Substitution.new(it)] }
          end

          private

          # A message with 27 free variables has other problems.
          def letter(index)
            LETTERS[index] || "t#{index - LETTERS.size + 1}"
          end
        end
      end
    end
  end
end
