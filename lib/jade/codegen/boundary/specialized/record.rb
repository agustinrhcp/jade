module Jade
  module Codegen
    module Boundary
      module Specialized
        # Structs whose fields are all specializable. Each specializable
        # struct gets a pair of `def self.decode_<name>` / `encode_<name>`
        # helper methods emitted at module level; the wrapper body for
        # `birthday(person: Person) -> Person` becomes
        # `encode_person(Internal.birthday(decode_person(person)))`.
        #
        # Cycle detection: a struct referencing itself (directly or
        # mutually) falls back to the descriptor cache path. The `seen`
        # set carries qnames of structs we're currently inside; revisiting
        # one means we'd loop, so we bail with nil.
        module Record
          extend self
          extend Helpers

          def decode(type, input, registry)
            struct = struct_for(type, registry) or return nil
            "#{decode_helper_name(struct)}(#{input})"
          end

          def encode(type, value_expr, registry)
            struct = struct_for(type, registry) or return nil
            "#{encode_helper_name(struct)}(#{value_expr})"
          end

          def specializable?(type, registry, seen)
            specializable_struct(type, registry, seen) ? true : false
          end

          # All specializable structs reachable from any exposed
          # function's boundary signature, transitively (through nested
          # struct fields and `List` / `Maybe` wrappers). Each one needs
          # `decode_<name>` / `encode_<name>` helper methods emitted.
          def collect_helpers(body, registry)
            body.expressions
              .filter { it.is_a?(AST::FunctionDeclaration) }
              .flat_map { fn_reachable_structs(it, registry) }
              .uniq
              .then { transitive_closure(it, registry) }
          end

          def emit_helpers(structs, registry)
            structs.flat_map do
              [decode_helper(it, registry), encode_helper(it, registry)]
            end
          end

          def struct_for(type, registry)
            specializable_struct(type, registry, ::Set.new)
          end

          # Returns specializable structs reachable from `type` through
          # any depth of `List` / `Maybe` / nested struct fields. Used by
          # `collect_helpers` to seed the closure walk.
          def structs_in(type, registry)
            if (struct = struct_for(type, registry))
              [struct]
            elsif (inner = List.inner_of(type))
              structs_in(inner, registry)
            elsif (inner = Maybe.inner_of(type))
              structs_in(inner, registry)
            else
              []
            end
          end

          private

          def specializable_struct(type, registry, seen)
            struct = lookup_struct(type, registry) or return nil
            return nil if seen.include?(struct.qualified_name)

            struct.record_type.fields.values
              .all? { Specialized.specializable_field?(it, registry, seen + [struct.qualified_name]) }
              .then { it ? struct : nil }
          end

          def lookup_struct(type, registry)
            return nil unless Specialized.args_of(type) == []
            qname = Specialized.qname_of(type) or return nil

            parts = qname.split('.')
            ref   = Symbol.type_ref(parts[0..-2].join('.'), parts[-1])
            sym   = registry.lookup(ref) or return nil
            sym.is_a?(Symbol::Struct) ? sym : nil
          end

          # Reachability walk from `seeds` through nested struct fields.
          # Pure-functional: each call builds a fresh `collected + frontier`.
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
            struct.record_type.fields.values.flat_map { structs_in(it, registry) }
          end

          def fn_reachable_structs(fn_node, registry)
            symbol = fn_node.symbol
            return [] unless registry.get(symbol.module_name).exposed_value(symbol.name)

            fn_type = registry.get(symbol.module_name)
              .env
              .then { it.substitution.apply(it.bindings[symbol.qualified_name].type) }

            args, ret = Type.signature(fn_type)
            (args + [ret]).flat_map { structs_in(it, registry) }
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
            Specialized.decode_expr(type, "h[#{key.to_s.inspect}]", registry) ||
              fail("non-specializable field type for #{key}: #{type}")
          end

          def field_encode_value(type, accessor, registry)
            Specialized.encode_expr(type, accessor, registry) || accessor
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
end
