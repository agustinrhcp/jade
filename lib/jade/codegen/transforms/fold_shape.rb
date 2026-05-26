module Jade
  module Codegen
    module Transforms
      module FoldShape
        extend self
        extend Helpers

        ACC_NAME = '__fold_acc__'

        # The right-fold shape:
        #
        #   def f(xs) ->
        #     case xs
        #       of []          -> BASE          (no self-call)
        #       of [h | rest]  -> COMBINE       (exactly one f(rest), strict)
        #
        # Returns a shape hash, or nil if the body doesn't match.
        def shape_for(body, self_sym, param_names, registry)
          return nil unless param_names.size == 1

          sig = [self_sym, 1]
          expr = unwrap_body(body)
          return nil unless expr.is_a?(AST::CaseOf)
          return nil unless expr.branches.size == 2

          list_arg = param_names.first
          return nil unless subject_is_arg?(expr.expression, list_arg)

          empty_branch = expr.branches.find { empty_list_pattern?(it.pattern) }
          cons_branch = expr.branches.find { cons_pattern?(it.pattern) }
          return nil unless empty_branch && cons_branch
          return nil if SelfCall.contains_self_call?(
            empty_branch.body, sig, registry
          )

          head_name = head_binding_name(cons_branch.pattern)
          rest_name = rest_binding_name(cons_branch.pattern)
          return nil unless head_name && rest_name

          calls = strict_self_calls(cons_branch.body, sig, registry)
          return nil unless calls&.size == 1

          call = calls.first
          return nil unless call.args.size == 1

          arg = call.args.first
          return nil unless arg in AST::VariableReference(name: ^rest_name)
          return nil unless rest_used_only?(cons_branch.body, rest_name, call)

          {
            list_arg: list_arg,
            base: empty_branch.body,
            head_name: head_name,
            combine: cons_branch.body,
            self_call: call,
          }
        end

        # Emits `xs.reverse.reduce(BASE) { |acc, head| COMBINE' }`. The
        # `reverse` gives right-associative combine order regardless of the
        # combiner's algebraic properties. Task effects are unaffected by
        # build order — only the final Task chain shape determines run-time
        # behavior.
        def generate_body(shape, registry)
          shape => { list_arg:, base:, head_name:, combine:, self_call: }

          base_code = generate_node(base, registry)
          combine_code = substitute(combine, self_call)
            .then { generate_node(it, registry) }

          "#{list_arg}.reverse.reduce(#{base_code}) " \
            "{ |#{ACC_NAME}, #{head_name}| #{combine_code} }"
        end

        private

        def unwrap_body(node)
          case node
          in AST::Body(expressions: [single]) then unwrap_body(single)
          in AST::Grouping(expression:) then unwrap_body(expression)
          else node
          end
        end

        def subject_is_arg?(expression, arg_name)
          expression in AST::VariableReference(name: ^arg_name)
        end

        def empty_list_pattern?(pattern)
          pattern in AST::Pattern::List(patterns: [], rest: nil)
        end

        # Only binding/wildcard heads qualify. Literal or constructor heads
        # (`[True | rest]`, `[1 | rest]`) make the source function partial
        # over the head; folding it would silently widen it to total.
        def cons_pattern?(pattern)
          case pattern
          in AST::Pattern::List(
            patterns: [AST::Pattern::Binding | AST::Pattern::Wildcard],
            rest: AST::Pattern::Binding
          ) then true
          else false
          end
        end

        def rest_binding_name(pattern)
          case pattern
          in AST::Pattern::List(rest: AST::Pattern::Binding(name:)) then name
          else nil
          end
        end

        def head_binding_name(pattern)
          case pattern
          in AST::Pattern::List(patterns: [AST::Pattern::Binding(name:)])
            name

          in AST::Pattern::List(patterns: [AST::Pattern::Wildcard])
            '_'

          else
            nil
          end
        end

        # The emitted block binds only `head` and `acc` — not `rest`. Any
        # reference to `rest` in COMBINE outside the chosen self-call's
        # argument would emit unbound Ruby.
        def rest_used_only?(node, rest_name, call)
          return true if node.equal?(call)
          return false if node in AST::VariableReference(name: ^rest_name)

          SelfCall.child_values(node)
            .all? { rest_check_value(it, rest_name, call) }
        end

        def rest_check_value(value, rest_name, call)
          case value
          when Array then value.all? { rest_check_value(it, rest_name, call) }
          when AST::Node then rest_used_only?(value, rest_name, call)
          else true
          end
        end

        # Collects self-calls in strict (always-evaluated) positions. Returns
        # nil when any self-call sits in a lazy position — a Lambda body,
        # an If branch, or a Case branch body — because `reduce` walks every
        # element unconditionally and can't skip or duplicate the recursive
        # step the way the source might.
        def strict_self_calls(node, sig, registry)
          deep = ->(n) {
            SelfCall.contains_self_call_anywhere?(n, sig, registry)
          }

          case node
          in AST::FunctionCall if SelfCall.self_call?(node, sig, registry)
            return nil if node.args.any? { deep.call(it) }
            [node]

          in AST::Lambda
            deep.call(node) ? nil : []

          in AST::IfThenElse(condition:, if_branch:, else_branch:)
            return nil if deep.call(if_branch)
            return nil if deep.call(else_branch)
            strict_self_calls(condition, sig, registry)

          in AST::CaseOf(expression:, branches:)
            return nil if branches.any? { deep.call(it.body) }
            strict_self_calls(expression, sig, registry)

          else
            SelfCall.child_values(node)
              .map { collect_strict_value(it, sig, registry) }
              .then { it.any?(&:nil?) ? nil : it.flatten(1) }
          end
        end

        def collect_strict_value(value, sig, registry)
          case value
          when Array
            value
              .map { collect_strict_value(it, sig, registry) }
              .then { it.any?(&:nil?) ? nil : it.flatten(1) }
          when AST::Node
            strict_self_calls(value, sig, registry)
          else
            []
          end
        end

        # AST nodes are immutable Data; rebuilds the tree with `target`
        # replaced by a fresh `__fold_acc__` reference.
        def substitute(node, target)
          return acc_var_ref if node.equal?(target)
          return node unless node.is_a?(AST::Node)

          node
            .to_h
            .transform_values { substitute_value(it, target) }
            .then { node.class.new(**it) }
        end

        def substitute_value(value, target)
          case value
          when Array then value.map { substitute_value(it, target) }
          when AST::Node then substitute(value, target)
          else value
          end
        end

        def acc_var_ref
          AST::VariableReference.new(
            name: ACC_NAME,
            symbol: Symbol::Variable.new(name: ACC_NAME, decl_span: nil),
            range: nil,
          )
        end
      end
    end
  end
end
