require 'jade/codegen/boundary/specialized/scalar'
require 'jade/codegen/boundary/specialized/list'
require 'jade/codegen/boundary/specialized/maybe'
require 'jade/codegen/boundary/specialized/record'

module Jade
  module Codegen
    module Boundary
      # Emits inline boundary code for known-shape types — scalars,
      # `List(specializable)`, `Maybe(specializable)`, and structs whose
      # fields are all specializable. Bypasses `Decode::Runner` and the
      # descriptor cache.
      #
      # This module is the dispatcher: each shape (`Scalar`, `List`,
      # `Maybe`, `Record`) lives in its own file under `specialized/`,
      # exposing `decode` / `encode` / `specializable?` methods that the
      # dispatcher tries in order. Shapes that contain other types
      # (`List`, `Maybe`, `Record`) recurse back through the dispatcher.
      module Specialized
        extend self

        # Ruby expression that validates `input` and yields the decoded
        # value, or `nil` if `type` isn't specializable.
        def decode_expr(type, input, registry)
          Scalar.decode(type, input) ||
            List.decode(type, input, registry) ||
            Maybe.decode(type, input, registry) ||
            Record.decode(type, input, registry)
        end

        # Ruby expression that encodes `value_expr` to the wire form, or
        # `nil` if the encoder is identity (caller skips the wrap) or the
        # type isn't specializable (caller falls back to the cache).
        def encode_expr(type, value_expr, registry)
          Record.encode(type, value_expr, registry) ||
            List.encode(type, value_expr, registry) ||
            Maybe.encode(type, value_expr, registry)
        end

        # True when the encoder for `type` produces output equal to the
        # input — the boundary wrapper can skip the encode call entirely.
        # Recursive: `List(t)` is identity iff `t` is.
        def identity_encoder?(type)
          Scalar.identity_encoder?(type) || List.identity_encoder?(type)
        end

        # Predicate used by `Record.specializable_struct` when checking
        # field types. The `seen` set carries struct qnames we're already
        # inside, threaded through container shapes for cycle detection.
        def specializable_field?(type, registry, seen)
          Scalar.specializable?(type, registry, seen) ||
            List.specializable?(type, registry, seen) ||
            Maybe.specializable?(type, registry, seen) ||
            Record.specializable?(type, registry, seen)
        end

        def collect_helpers(body, registry)
          Record.collect_helpers(body, registry)
        end

        def emit_helpers(structs, registry)
          Record.emit_helpers(structs, registry)
        end

        # --- type-shape helpers shared across shape modules ---

        # Both `Type::Application` (from inferred boundary types) and
        # `Symbol::TypeApplication` (from struct field declarations) carry
        # the same constructor/args shape; normalize to a qname string.
        def qname_of(type)
          case type
          in Type::Application(constructor: Type::Constructor(name:))
            name

          in Symbol::TypeApplication(constructor: Symbol::TypeRef(module_name:, name: n))
            "#{module_name}.#{n}"

          else
            nil
          end
        end

        def args_of(type)
          case type
          in Type::Application(args:)         then args
          in Symbol::TypeApplication(args:)   then args
          else                                     nil
          end
        end

        # Human-readable label for error messages on container types.
        def type_label(type)
          if (qname = Scalar.qname_for(type))
            Scalar::LABEL[qname]
          elsif (inner = List.inner_of(type))
            "List(#{type_label(inner)})"
          elsif (inner = Maybe.inner_of(type))
            "Maybe(#{type_label(inner)})"
          else
            (qname_of(type) || 'value').split('.').last
          end
        end
      end
    end
  end
end
