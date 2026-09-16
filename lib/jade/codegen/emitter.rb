require 'jade/codegen/helpers'

module Jade
  module Codegen
    module Emitter
      extend self
      extend Helpers

      def emit(ir, registry = nil)
        case ir
        in [:var, expr]
          expr

        in [:!, expr]
          "!(#{emit(expr, registry)})"

        in [:and, expr1, expr2]
          "#{emit(expr1, registry)} && #{emit(expr2, registry)}"

        in [:==, expr1, expr2]
          "#{emit(expr1, registry)} == #{emit(expr2, registry)}"

        in Integer | TrueClass | FalseClass | Float
          ir.to_s

        in String
          ir.inspect

        in [:case, subject, branches]
          branches
            .map { [:case_branch, *it] }
            .map { emit(it, registry) }
            .join("\n")
            .then { "case #{emit(subject, registry)}\n#{it}\nend" }

        in [:case_branch, pattern, body]
          body
            .map { emit(it, registry) }.join('; ')
            .then { "in #{emit(pattern, registry)} then #{it}" }

        in [:call, callee, args]
          args
            .map { emit(it, registry) }
            .join(', ')
            .then { "#{emit(callee, registry)}.call(#{it})"}

        in [:impl_arg, index, fn]
          "impl_arg[#{index}]['#{fn}']"

        in [:impl_dict, index]
          "impl_arg[#{index}]"

        in [:fn, qualified_name]
          fn_reference(qualified_name, [], registry)

        in [:fn, qualified_name, dict_indices]
          fn_reference(qualified_name, dict_indices, registry)

        in [:stdlib_fn, name]
          "Jade::Runtime.intr(#{name.inspect})"

        in [:struct_constructor, qualified_name, arity]
          "Jade::Runtime.curry(::#{to_qualified(qualified_name)}.method(:[]), #{arity})"

        in [:struct_class, qualified_name]
          "::#{to_qualified(qualified_name)}"

        in [:anon_record_class, keys]
          record_class(keys)

        in [:list, exprs]
          exprs
            .map { emit(it, registry) }
            .join(', ')
            .then { "[#{it}]" }

        in [:hash, pairs]
          pairs
            .map { |key, value| "#{key.inspect} => #{emit(value, registry)}" }
            .join(', ')
            .then { it.empty? ? '{}' : "{ #{it} }" }

        in [:access, expr, key]
          "#{emit(expr, registry)}.#{key}"

        # patterns

        in [:constructor, name, args]
          args
            .map { "#{it}" }
            .join(',')
            .then { "::#{to_qualified(name)}(#{it})" }

        in [:_]
          '_'

        end
      end

      private

      def fn_reference(qualified_name, dict_indices, registry)
        registry or fail("[:fn, #{qualified_name.inspect}] needs a registry")

        *module_parts, name = qualified_name.split('.')

        Symbol
          .value_ref(module_parts.join('.'), name)
          .then { registry.lookup(it) }
          .then { checked_reference(it, qualified_name, dict_indices, registry) }
      end

      def checked_reference(symbol, qualified_name, dict_indices, registry)
        wanted = dict_constraints(symbol, registry).size

        unless wanted == dict_indices.size
          fail(
            "#{qualified_name} takes #{wanted} #{wanted == 1 ? 'dictionary' : 'dictionaries'}, " \
              "#{dict_indices.size} given — a derived body passes one impl_arg " \
              'index per constraint, in the order the callee declares them'
          )
        end

        target = "#{internal(symbol.module_name)}.#{fn_target_name(symbol, registry)}"
        return "#{internal(symbol.module_name)}.method(:#{fn_target_name(symbol, registry)})" if wanted.zero?

        dict_indices
          .map { "impl_arg[#{it}]" }
          .join(', ')
          .then { "->(*args) { #{target}(*args, #{it}) }" }
      end

    end
  end
end
