module Jade
  module Frontend
    module Desugaring
      extend self
      extend Codegen::Helpers

      # Runs after SemanticAnalysis (which resolves names and attaches
      # symbols). Add new post-resolution rewrites as `in` branches
      # below; `map_children` handles transparent recursion.
      def desugar_resolved_entry(entry, registry)
        desugar_resolved(entry.ast, registry)
          .then { entry.with(ast: it) }
      end

      def desugar_resolved(node, registry)
        case node
        in AST::CurriedConstructor
          curry_constructor(node, registry)

        in AST::VariableReference | AST::QualifiedAccess
          zero_arg_fn?(node.symbol, registry) ? wrap_call(node) : node

        else
          map_children(node) { desugar_resolved(it, registry) }
        end
      end

      private

      # `^C` is `C(_, _, …)` with the arity filled in — which needs the
      # resolved symbol, so it cannot be done at parse time.
      def curry_constructor(node, registry)
        arity = registry.lookup(node.symbol)&.args&.length || 0
        names = (0...arity).map { param_synthetic_name(it) }

        AST::FunctionCall
          .new(
            callee: AST::ConstructorReference[node.name, node.range].with(symbol: node.symbol),
            args: names.map { AST::VariableReference[it, node.range].with(symbol: Symbol.var(it, nil)) },
            infix: false,
            dictionaries: [],
            range: node.range,
            symbol: nil,
            id: node.id,
            leading_comments: node.leading_comments,
            trailing_comments: node.trailing_comments,
            dangling_comments: node.dangling_comments,
            trailing_comma: false,
          )
          .then do |call|
            names.reverse.reduce(call) do |body, name|
              AST::Lambda[
                [AST::Pattern::Binding[name, node.range]],
                AST::Body[[body], node.range],
                node.range,
              ]
            end
          end
      end

      def map_children(node)
        node
          .to_h
          .transform_values { walk_field(it) { yield(it) } }
          .then { node.class.new(**it) }
      end

      # AST node fields are either an AST::Node, an array of AST::Nodes,
      # or non-AST metadata (range, symbol, id, comments, bools). The
      # block walks the first two; metadata passes through untouched.
      def walk_field(value, &block)
        case value
        in AST::Node then block.call(value)
        in [AST::Node, *] then value.map(&block)
        else value
        end
      end

      def wrap_call(ref)
        AST::FunctionCall.new(
          callee: ref,
          args: [],
          infix: false,
          dictionaries: [],
          range: ref.range,
        )
      end

      def zero_arg_fn?(symbol, registry)
        resolved = symbol.is_a?(Symbol::ValueRef) ? registry.lookup(symbol) : symbol
        case resolved
        in Symbol::Function | Symbol::StdlibFunction => fn then fn.constant?
        else false
        end
      end
    end
  end
end
