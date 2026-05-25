module Jade
  module Frontend
    module Desugaring
      extend self

      # Runs after SemanticAnalysis (which resolves names and attaches
      # symbols). Add new post-resolution rewrites as `in` branches
      # below; `map_children` handles transparent recursion.
      def desugar_resolved_entry(entry, registry)
        desugar_resolved(entry.ast, registry)
          .then { entry.with(ast: it) }
      end

      def desugar_resolved(node, registry)
        case node
        in AST::VariableReference | AST::QualifiedAccess
          zero_arg_fn?(node.symbol, registry) ? wrap_call(node) : node

        else
          map_children(node) { desugar_resolved(it, registry) }
        end
      end

      private

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
