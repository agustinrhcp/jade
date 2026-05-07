require 'jade/codegen/helpers'

module Jade
  module Codegen
    module Emitter
      extend self
      extend Helpers

      def emit(ir)
        case ir
        in [:var, expr]
          expr

        in [:!, expr]
          "!(#{emit(expr)})"

        in [:and, expr1, expr2]
          "#{emit(expr1)} && #{emit(expr2)}"

        in Integer | TrueClass | FalseClass | Float
          ir.to_s

        in String
          ir.inspect

        in [:case, subject, branches]
          branches
            .map { [:case_branch, *it] }
            .map { emit(it) }
            .join('; ')
            .then { "case #{emit(subject)}; #{it}; end" }

        in [:case_branch, pattern, body]
          body
            .map { emit(it) }.join('; ')
            .then { "in #{emit(pattern)} then #{it}" }

        in [:call, callee, args]
          args
            .map { emit(it) }
            .join(', ')
            .then { "#{emit(callee)}.call(#{it})"}

        in [:impl_arg, index, fn]
          "impl_arg[#{index}]['#{fn}']"

        in [:stdlib_fn, name]
          "Jade::Runtime.intr(#{name.inspect})"

        in [:raw, code]
          code

        in [:list, exprs]
          exprs
            .map { emit(it) }
            .join(', ')
            .then { "[#{it}]" }

        in [:access, expr, key]
          "#{emit(expr)}.#{key}"

        # patterns

        in [:constructor, name, args]
          args
            .map { "#{it}" }
            .join(',')
            .then { "#{to_qualified(name)}(#{it})" }

        in [:_]
          '_'

        end
      end

    end
  end
end
