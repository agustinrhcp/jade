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

          def decode(type, input, registry, where = nil)
            inner = inner_of(type) or return nil

            scalar_optimized(inner, input, where) ||
              generic_decode(type, inner, input, registry, where)
          end

          def encode(type, value_expr, registry)
            inner_of(type)
              &.then { Specialized.encode_expr(it, '_1', registry) }
              &.then { map_expr(it, value_expr) }
          end

          def map_expr(elem, value_expr)
            case elem
            in ::String then "#{value_expr}.map { #{elem} }"
            in :identity then nil
            end
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
          def scalar_optimized(inner, input, where)
            qname = Scalar.qname_for(inner) or return nil
            klass = Scalar::LIST_ELEM_CLASS[qname]
            label = "List(#{Scalar::LABEL[qname]})".inspect
            "Jade::Interop::Boundary.list_of(#{klass}, #{label}, #{input}#{Specialized.where_arg(where)})"
          end

          # The index comes from `elements`, so the element decoder itself
          # carries no path of its own.
          def generic_decode(type, inner, input, registry, where)
            elem = Specialized.decode_expr(inner, '_1', registry) or return nil
            label = "List(#{Specialized.type_label(inner)})".inspect
            at = Specialized.where_arg(where)
            array = "Jade::Interop::Boundary.array(#{label}, #{input}#{at})"
            "Jade::Interop::Boundary.elements(#{array}#{at}) { #{elem} }"
          end
        end
      end
    end
  end
end
