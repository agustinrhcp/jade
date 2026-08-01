module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ConstructorNotFound < Jade::Error
          # `fix` is where the `(..)` is missing: `:expose` when the module
          # that owns the type keeps its constructors to itself, `:import`
          # when it exposes them and this module's import didn't ask for them.
          Hint = Data.define(:module_name, :type_name, :fix)

          attr_reader :candidates

          def initialize(entry, span, name:, hint: nil, candidates: [])
            @name = name
            @hint = hint
            @candidates = candidates
            super(entry:, span:)
          end

          def message
            base = "I cannot find a `#{@name}` constructor"

            case @hint
            in nil
              base

            in Hint(module_name:, type_name:, fix: :expose)
              "#{base}. The type `#{type_name}` is exposed by `#{module_name}` but its " \
                "constructor is private — add `#{type_name}(..)` to that module's " \
                "`exposing` list."

            in Hint(module_name:, type_name:, fix: :import)
              "#{base}. `#{module_name}` exposes it — add `#{type_name}(..)` to this " \
                "module's `import #{module_name} exposing (...)`."
            end
          end

          def label
            "not found"
          end

          def queried_name
            @name
          end
        end
      end
    end
  end
end
