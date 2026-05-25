module Jade
  module Codegen
    module TailCall
      extend self
      extend Helpers

      METADATA_KEYS = %i[
        range symbol id
        leading_comments trailing_comments dangling_comments
        trailing_comma
      ].freeze

      def tail_recursive?(body, self_sym, arity, registry)
        classify(body, [self_sym, arity], registry) == :tail
      end

      def generate_body(body, registry, self_sym, param_names)
        emit_tail(body, registry, [self_sym, param_names.size], param_names)
          .then { Pretty.block("loop do", it) }
      end

      private

      def classify(node, self_sym, registry)
        case node
        in AST::FunctionCall if self_call?(node, self_sym, registry)
          node.args.any? { contains_self_call?(it, self_sym, registry) } \
            ? :non_tail
            : :tail

        in AST::Body(expressions:)
          *leading, last = expressions
          if leading.any? { contains_self_call?(it, self_sym, registry) }
            :non_tail
          else
            classify(last, self_sym, registry)
          end

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          if contains_self_call?(condition, self_sym, registry)
            :non_tail
          else
            combine(
              classify(if_branch, self_sym, registry),
              classify(else_branch, self_sym, registry),
            )
          end

        in AST::CaseOf(expression:, branches:)
          if contains_self_call?(expression, self_sym, registry)
            :non_tail
          else
            branches
              .map { classify(it.body, self_sym, registry) }
              .reduce(:none) { |acc, c| combine(acc, c) }
          end

        in AST::Grouping(expression:)
          classify(expression, self_sym, registry)

        else
          contains_self_call?(node, self_sym, registry) ? :non_tail : :none
        end
      end

      def combine(a, b)
        return :non_tail if a == :non_tail || b == :non_tail
        return :tail if a == :tail || b == :tail
        :none
      end

      def contains_self_call?(node, self_sym, registry)
        return true if node.is_a?(AST::FunctionCall) && self_call?(node, self_sym, registry)
        return false if node.is_a?(AST::Lambda)

        child_values(node).any? { walk_for_self_call(it, self_sym, registry) }
      end

      def walk_for_self_call(value, self_sym, registry)
        case value
        when Array then value.any? { walk_for_self_call(it, self_sym, registry) }
        when AST::Node then contains_self_call?(value, self_sym, registry)
        else false
        end
      end

      def child_values(node)
        node
          .to_h
          .reject { |k, _| METADATA_KEYS.include?(k) }
          .values
      end

      def self_call?(call, self_sig, registry)
        self_sym, arity = self_sig
        resolved =
          case call.callee.symbol
          in Symbol::ValueRef => ref then registry.lookup(ref)
          in s then s
          end

        resolved.is_a?(Symbol::Function) &&
          resolved.module_name == self_sym.module_name &&
          resolved.name == self_sym.name &&
          call.args.size == arity
      end

      def emit_tail(node, registry, self_sym, param_names)
        case node
        in AST::FunctionCall if self_call?(node, self_sym, registry)
          node
            .args
            .map { generate_node(it, registry) }
            .join(', ')
            .then { "#{param_names.join(', ')} = #{it}" }

        in AST::Body(expressions:)
          *leading, last = expressions
          [
            *leading.map { generate_node(it, registry) },
            emit_tail(last, registry, self_sym, param_names),
          ].join("\n")

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          [
            "if (#{generate_node(condition, registry)})",
            Pretty.indent(emit_tail(if_branch, registry, self_sym, param_names)),
            "else",
            Pretty.indent(emit_tail(else_branch, registry, self_sym, param_names)),
            "end",
          ].join("\n")

        in AST::CaseOf(expression:, branches:)
          branches
            .map { emit_tail_branch(it, registry, self_sym, param_names) }
            .join("\n")
            .then { "case #{generate_node(expression, registry)}\n#{it}\nend" }

        in AST::Grouping(expression:)
          emit_tail(expression, registry, self_sym, param_names)

        else
          "break #{generate_node(node, registry)}"
        end
      end

      def emit_tail_branch(branch, registry, self_sym, param_names)
        pat = generate_node(branch.pattern, registry)
        body = emit_tail(branch.body, registry, self_sym, param_names)

        Pretty.multiline?(body) \
          ? "in #{pat} then\n#{Pretty.indent(body)}"
          : "in #{pat} then #{body}"
      end
    end
  end
end
