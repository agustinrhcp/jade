module Jade
  module Codegen
    module Transforms
      module TailCall
        extend self
        extend Helpers

        def tail_recursive?(body, self_sym, arity, registry)
          classify(body, [self_sym, arity], registry) == :tail
        end

        def generate_body(body, registry, self_sym, param_names)
          [self_sym, param_names.size]
            .then { emit_tail(body, registry, it, param_names) }
            .then { Pretty.block("loop do", it) }
        end

        private

        def classify(node, sig, registry)
          has_self = ->(n) { SelfCall.contains_self_call?(n, sig, registry) }

          case node
          in AST::FunctionCall if SelfCall.self_call?(node, sig, registry)
            node.args.any? { has_self.call(it) } ? :non_tail : :tail

          in AST::Body(expressions:)
            *leading, last = expressions
            if leading.any? { has_self.call(it) }
              :non_tail
            else
              classify(last, sig, registry)
            end

          in AST::IfThenElse(condition:, if_branch:, else_branch:)
            if has_self.call(condition)
              :non_tail
            else
              combine(
                classify(if_branch, sig, registry),
                classify(else_branch, sig, registry),
              )
            end

          in AST::CaseOf(expression:, branches:)
            if has_self.call(expression)
              :non_tail
            else
              branches
                .map { classify(it.body, sig, registry) }
                .reduce(:none) { |acc, c| combine(acc, c) }
            end

          in AST::Grouping(expression:)
            classify(expression, sig, registry)

          else
            has_self.call(node) ? :non_tail : :none
          end
        end

        def combine(a, b)
          return :non_tail if a == :non_tail || b == :non_tail
          return :tail if a == :tail || b == :tail
          :none
        end

        def emit_tail(node, registry, sig, params)
          case node
          in AST::FunctionCall if SelfCall.self_call?(node, sig, registry)
            node.args
              .map { generate_node(it, registry) }
              .join(', ')
              .then { "#{params.join(', ')} = #{it}" }

          in AST::Body(expressions:)
            *leading, last = expressions
            [
              *leading.map { generate_node(it, registry) },
              emit_tail(last, registry, sig, params),
            ].join("\n")

          in AST::IfThenElse(condition:, if_branch:, else_branch:)
            [
              "if (#{generate_node(condition, registry)})",
              Pretty.indent(emit_tail(if_branch, registry, sig, params)),
              "else",
              Pretty.indent(emit_tail(else_branch, registry, sig, params)),
              "end",
            ].join("\n")

          in AST::CaseOf(expression:, branches:)
            subject = generate_node(expression, registry)
            branches
              .map { emit_tail_branch(it, registry, sig, params) }
              .join("\n")
              .then { "case #{subject}\n#{it}\nend" }

          in AST::Grouping(expression:)
            emit_tail(expression, registry, sig, params)

          else
            "break #{generate_node(node, registry)}"
          end
        end

        def emit_tail_branch(branch, registry, sig, params)
          pat = generate_node(branch.pattern, registry)
          body = emit_tail(branch.body, registry, sig, params)

          if Pretty.multiline?(body)
            "in #{pat} then\n#{Pretty.indent(body)}"
          else
            "in #{pat} then #{body}"
          end
        end
      end
    end
  end
end
