module Jade
  module Codegen
    module Boundary
      module Specialized
        # `Maybe(t)` where `t` is itself specializable. Both decode and
        # encode bind the input via `.then { it ... }` so a complex
        # `value_expr` (e.g. a full `Internal.X(...)` call) isn't
        # re-evaluated.
        module Maybe
          extend self

          def decode(type, input, registry)
            inner = inner_of(type) or return nil
            elem = Specialized.decode_expr(inner, 'it', registry) or return nil

            "#{input}.then { it.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[#{elem}] }"
          end

          def encode(type, value_expr, registry)
            inner = inner_of(type) or return nil
            inner_enc = Specialized.encode_expr(inner, 'it._1', registry) || 'it._1'

            "#{value_expr}.then { it.is_a?(::Jade::Maybe::Just) ? #{inner_enc} : nil }"
          end

          def specializable?(type, registry, seen)
            inner = inner_of(type) or return false
            Specialized.specializable_field?(inner, registry, seen)
          end

          def inner_of(type)
            return nil unless Specialized.qname_of(type) == 'Maybe.Maybe'
            args = Specialized.args_of(type)
            args&.size == 1 ? args[0] : nil
          end
        end
      end
    end
  end
end
