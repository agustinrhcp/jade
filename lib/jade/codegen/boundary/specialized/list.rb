module Jade
  module Codegen
    module Boundary
      module Specialized
        # `List(t)` where `t` is itself specializable. Two shapes:
        #
        # - `List(scalar)` — emits a single `Array#all?` C-loop check via
        #   `Boundary.list_of`, then passes the array through.
        # - `List(specializable)` — validates Array shape with
        #   `Boundary.array`, then maps the inner decoder over each element.
        module List
          extend self

          def decode(type, input, registry)
            inner = inner_of(type) or return nil

            scalar_optimized(inner, input) ||
              generic_decode(type, inner, input, registry)
          end

          def encode(type, value_expr, registry)
            inner = inner_of(type) or return nil
            return nil if Specialized.identity_encoder?(inner)

            elem = Specialized.encode_expr(inner, '_1', registry) or return nil
            "#{value_expr}.map { #{elem} }"
          end

          def identity_encoder?(type)
            inner = inner_of(type) or return false
            Specialized.identity_encoder?(inner)
          end

          def specializable?(type, registry, seen)
            inner = inner_of(type) or return false
            Specialized.specializable_field?(inner, registry, seen)
          end

          def inner_of(type)
            return nil unless Specialized.qname_of(type) == 'List.List'
            args = Specialized.args_of(type)
            args&.size == 1 ? args[0] : nil
          end

          private

          # `List(scalar)` fast path: validate elements with a single
          # C-loop `all?` check, no per-element decoder call.
          def scalar_optimized(inner, input)
            qname = Scalar.qname_for(inner) or return nil
            klass = Scalar::LIST_ELEM_CLASS[qname]
            label = "List(#{Scalar::LABEL[qname]})".inspect
            "Jade::Interop::Boundary.list_of(#{klass}, #{label}, #{input})"
          end

          def generic_decode(type, inner, input, registry)
            elem = Specialized.decode_expr(inner, '_1', registry) or return nil
            label = "List(#{Specialized.type_label(inner)})".inspect
            "Jade::Interop::Boundary.array(#{label}, #{input}).map { #{elem} }"
          end
        end
      end
    end
  end
end
