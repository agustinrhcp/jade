module Jade
  module Codegen
    module Boundary
      # Per-module cache mapping each type a boundary wrapper needs to
      # decode/encode to a const name (`BOUNDARY_DEC_0`, etc.) that holds
      # the value once at module load. `collect` walks the body to build
      # the map; `decoder_for` / `encoder_for` consult it from wrapper
      # codegen, falling back to the raw `Boundary` spec when uncached
      # (e.g. when emission runs outside a Module).
      module Cache
        extend self
        extend Helpers

        def decoder_for(type, registry)
          Codegen.boundary_cache[:decoders][type] || Boundary.decoder_for(type, registry)
        end

        def encoder_for(type, registry)
          Codegen.boundary_cache[:encoders][type] || Boundary.encoder_for(type, registry)
        end

        def task_arms(task_type, registry)
          task_type => Type::Application(args: [ok_t, err_t])
          [encoder_for(ok_t, registry), encoder_for(err_t, registry)]
        end

        def collect(body, registry)
          per_fn = body
            .expressions
            .filter_map do
              boundary_types(it, registry) if it.is_a?(AST::FunctionDeclaration)
            end

          {
            decoders: cache_map(per_fn.flat_map { it[:decoders] }, 'DEC') { |t|
              Boundary::Specialized.decode_expr(t, '_')
            },
            encoders: cache_map(per_fn.flat_map { it[:encoders] }, 'ENC') { |t|
              Boundary::Specialized.identity_encoder?(t)
            },
          }
        end

        # Types with a specialized inline emission don't need a cached
        # constant — the wrapper emits the validation directly.
        def cache_map(types, tag, &specialized)
          types
            .reject(&specialized)
            .uniq
            .each_with_index
            .map { |t, i| [t, "BOUNDARY_#{tag}_#{i}"] }
            .to_h
        end

        def constants(cache, registry)
          cache[:decoders].map { |type, name| "#{name} = #{Boundary.decoder_for(type, registry)}" } +
            cache[:encoders].map { |type, name| "#{name} = #{Boundary.encoder_for(type, registry)}" }
        end

        private

        # Returns the {decoders:, encoders:} type lists this fn's wrapper
        # would touch, or `nil` when the fn produces no wrapper (not
        # exposed, polymorphic, or ineligible).
        def boundary_types(fn_node, registry)
          symbol = fn_node.symbol
          return nil unless registry.get(symbol.module_name).exposed_value(symbol.name)
          return nil unless dict_constraints(symbol, registry).empty?

          fn_type = fn_type_for(symbol, registry)
          return nil unless Boundary.eligible?(fn_type, registry)

          args, return_type = Type.signature(fn_type)

          case return_type
          in Type::Application(constructor: Type::Constructor(name: 'Task.Task'), args: arms)
            arms
          else
            [return_type]
          end
            .then { { decoders: args, encoders: it } }
        end

        def fn_type_for(symbol, registry)
          registry
            .get(symbol.module_name)
            .env
            .then { it.substitution.apply(it.bindings[symbol.qualified_name].type) }
        end
      end
    end
  end
end
