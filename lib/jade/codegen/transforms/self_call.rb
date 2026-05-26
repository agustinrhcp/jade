module Jade
  module Codegen
    module Transforms
      # AST-walking primitives for recognizing self-recursive calls. A
      # "self-call signature" is the pair `[self_sym, arity]`: a ValueRef
      # carrying module_name + name, paired with the function's user-declared
      # arity (partial applications never qualify).
      module SelfCall
        extend self

        METADATA_KEYS = %i[
          range symbol id
          leading_comments trailing_comments dangling_comments
          trailing_comma
        ].freeze

        # Defensive on `node` — anything that isn't a FunctionCall returns
        # false, so callers don't need to type-check before calling.
        def self_call?(node, sig, registry)
          return false unless node.is_a?(AST::FunctionCall)

          self_sym, arity = sig
          resolved = resolve(node.callee.symbol, registry)

          resolved.is_a?(Symbol::Function) &&
            resolved.module_name == self_sym.module_name &&
            resolved.name == self_sym.name &&
            node.args.size == arity
        end

        # Scope-aware: stops at Lambda boundaries. A self-call inside a
        # lambda body belongs to that lambda, not to the enclosing function.
        def contains_self_call?(node, sig, registry)
          return true if self_call?(node, sig, registry)
          return false if node.is_a?(AST::Lambda)

          child_descendants(node)
            .any? { contains_self_call?(it, sig, registry) }
        end

        # Scope-blind: descends into Lambda bodies. For disqualifying any
        # subtree that textually mentions a self-call at any depth.
        def contains_self_call_anywhere?(node, sig, registry)
          return true if self_call?(node, sig, registry)

          child_descendants(node)
            .any? { contains_self_call_anywhere?(it, sig, registry) }
        end

        def child_values(node)
          node
            .to_h
            .reject { |k, _| METADATA_KEYS.include?(k) }
            .values
        end

        private

        def resolve(symbol, registry)
          case symbol
          in Symbol::ValueRef => ref then registry.lookup(ref)
          in s then s
          end
        end

        # Flat list of direct AST::Node descendants, dipping into array
        # fields (e.g. FunctionCall#args) but skipping scalars.
        def child_descendants(node)
          child_values(node).flat_map do |v|
            case v
            when Array then v.grep(AST::Node)
            when AST::Node then [v]
            else []
            end
          end
        end
      end
    end
  end
end
