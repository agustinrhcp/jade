module Jade
  module Codegen
    module Boundary
      # Emits inline boundary code for known-shape types — `Int`, `Float`,
      # `Bool`, `String`, `List(scalar)`, and structs whose fields are all
      # specializable (scalars, lists of scalar, or nested specializable
      # structs). Bypasses `Decode::Runner` and the descriptor cache. For
      # structs, emits a pair of `decode_<name>` / `encode_<name>` helper
      # methods at module level; wrapper bodies call those instead of
      # nested `decode_or_raise` / encoder closures.
      module Specialized
        extend self
        extend Helpers

        SCALAR_HELPER = {
          'Basics.Int'    => 'integer',
          'Basics.Float'  => 'float',
          'Basics.Bool'   => 'bool',
          'String.String' => 'string',
        }.freeze

        SCALAR_LABEL = {
          'Basics.Int'    => 'Int',
          'Basics.Float'  => 'Float',
          'Basics.Bool'   => 'Bool',
          'String.String' => 'String',
        }.freeze

        LIST_ELEM_CLASS = {
          'Basics.Int'    => '::Integer',
          'Basics.Float'  => '::Numeric',
          'Basics.Bool'   => '::TrueClass',
          'String.String' => '::String',
        }.freeze

        # Returns a Ruby expression that validates `input` and yields the
        # decoded value, or `nil` if `type` isn't specializable.
        def decode_expr(type, input, registry)
          if (qname = scalar_qname(type))
            scalar_call(qname, input)
          elsif (qname = list_scalar_qname(type))
            list_call(qname, input)
          elsif (struct = record_struct(type, registry))
            "#{decode_helper_name(struct)}(#{input})"
          end
        end

        # Returns a Ruby expression that encodes `value_expr` to the wire
        # form, or `nil` if `type` isn't a record (scalars/lists go through
        # `identity_encoder?` + skip; everything else falls back to the
        # cached encoder closure).
        def encode_expr(type, value_expr, registry)
          struct = record_struct(type, registry) or return nil
          "#{encode_helper_name(struct)}(#{value_expr})"
        end

        # True when the encoder for `type` is the identity function — the
        # boundary wrapper can skip the encode call entirely.
        def identity_encoder?(type)
          scalar_qname(type) || list_scalar_qname(type) ? true : false
        end

        # Walks the module body for record types referenced by exposed
        # function boundaries; returns the distinct `Symbol::Struct`s that
        # are specializable, plus all specializable structs they reach
        # through nested fields (so the helper for an outer record can
        # call the helper for an inner one).
        def collect_helpers(body, registry)
          body.expressions
            .filter { it.is_a?(AST::FunctionDeclaration) }
            .flat_map { fn_record_types(it, registry) }
            .uniq
            .then { transitive_closure(it, registry) }
        end

        # Emits the `decode_<name>` / `encode_<name>` methods for each
        # collected struct. Returns an array of Ruby def strings.
        def emit_helpers(structs, registry)
          structs.flat_map do
            [decode_helper(it, registry), encode_helper(it, registry)]
          end
        end

        private

        def scalar_qname(type)
          return nil unless args_of(type) == []

          qname_of(type).then { SCALAR_HELPER.key?(it) ? it : nil }
        end

        def list_scalar_qname(type)
          return nil unless qname_of(type) == 'List.List'
          args = args_of(type)
          return nil unless args&.size == 1

          scalar_qname(args[0])
        end

        # Returns the Symbol::Struct when `type` is a specializable struct
        # — every field is scalar, list-of-scalar, or another
        # specializable struct. Cycles fall back to the cache path.
        def record_struct(type, registry)
          specializable_struct(type, registry, ::Set.new)
        end

        # `seen` carries the qnames of structs we're currently inside,
        # so a recursive descent into a self- or mutually-referential
        # struct bails instead of looping. Non-mutating: each recursion
        # gets a fresh `seen + [name]` set.
        def specializable_struct(type, registry, seen)
          struct = lookup_struct(type, registry) or return nil
          return nil if seen.include?(struct.qualified_name)

          struct.record_type.fields.values
            .all? { specializable_field?(it, registry, seen + [struct.qualified_name]) }
            .then { it ? struct : nil }
        end

        def specializable_field?(type, registry, seen)
          scalar_qname(type) ||
            list_scalar_qname(type) ||
            specializable_struct(type, registry, seen)
        end

        def lookup_struct(type, registry)
          return nil unless args_of(type) == []
          qname = qname_of(type) or return nil

          parts = qname.split('.')
          ref   = Symbol.type_ref(parts[0..-2].join('.'), parts[-1])
          sym   = registry.lookup(ref) or return nil
          sym.is_a?(Symbol::Struct) ? sym : nil
        end

        # Reachability walk from `seeds` through nested struct fields.
        # On each step we process only the structs we haven't seen yet
        # (`frontier`), accumulate them into `collected`, and recurse on
        # the structs they reach. Stops when the frontier is empty.
        def transitive_closure(seeds, registry, collected = ::Set.new)
          frontier = seeds.reject { collected.include?(it) }
          return collected.to_a if frontier.empty?

          transitive_closure(
            frontier.flat_map { nested_structs(it, registry) },
            registry,
            collected + frontier,
          )
        end

        def nested_structs(struct, registry)
          struct.record_type.fields.values.filter_map do
            specializable_struct(it, registry, ::Set.new)
          end
        end

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

        def fn_record_types(fn_node, registry)
          symbol = fn_node.symbol
          return [] unless registry.get(symbol.module_name).exposed_value(symbol.name)

          fn_type = registry.get(symbol.module_name)
            .env
            .then { it.substitution.apply(it.bindings[symbol.qualified_name].type) }

          args, ret = Type.signature(fn_type)
          (args + [ret]).filter_map { record_struct(it, registry) }
        end

        def scalar_call(qname, input)
          helper = SCALAR_HELPER[qname]
          label  = SCALAR_LABEL[qname].inspect
          "Jade::Interop::Boundary.#{helper}(#{label}, #{input})"
        end

        def list_call(inner_qname, input)
          klass = LIST_ELEM_CLASS[inner_qname]
          label = "List(#{SCALAR_LABEL[inner_qname]})".inspect
          "Jade::Interop::Boundary.list_of(#{klass}, #{label}, #{input})"
        end

        def decode_helper_name(struct)
          "decode_#{snake(struct.name)}"
        end

        def encode_helper_name(struct)
          "encode_#{snake(struct.name)}"
        end

        def decode_helper(struct, registry)
          ctor      = "::#{to_qualified(struct.module_name)}::#{struct.name}"
          hash_call = "Jade::Interop::Boundary.hash(#{struct.name.inspect}, value)"

          struct.record_type.fields
            .map { |k, t| field_decode(k, t, registry) }
            .then { Pretty.call(ctor, it, open: '[', close: ']') }
            .then { Pretty.block("#{hash_call}.then do |h|", it) }
            .then { Pretty.block("def self.#{decode_helper_name(struct)}(value)", it) }
        end

        def encode_helper(struct, registry)
          struct.record_type.fields
            .map { |k, t| "#{k.inspect} => #{field_encode_value(t, "p.#{k}", registry)}" }
            .then { "{ #{it.join(', ')} }" }
            .then { Pretty.block("def self.#{encode_helper_name(struct)}(p)", it) }
        end

        def field_decode(key, type, registry)
          decode_expr(type, "h[#{key.to_s.inspect}]", registry) ||
            fail("non-specializable field type for #{key}: #{type}")
        end

        def field_encode_value(type, accessor, registry)
          if scalar_qname(type) || list_scalar_qname(type)
            accessor
          elsif (struct = record_struct(type, registry))
            "#{encode_helper_name(struct)}(#{accessor})"
          else
            fail("non-specializable field encode for #{type}")
          end
        end

        def snake(name)
          name
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end
      end
    end
  end
end
