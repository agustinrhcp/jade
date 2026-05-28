module Jade
  module Formatter
    # Simple leaf nodes: each is at most a one-liner of formatting logic.
    # Grouped here so the per-node directory doesn't drown in trivia.

    module VariableReference
      extend self
      extend Helper

      def format(node, indent:, source:)
        node.name.then(&and_indent(indent))
      end
    end

    module ConstructorReference
      extend self
      extend Helper

      def format(node, indent:, source:)
        node.name.then(&and_indent(indent))
      end
    end

    module CharLiteral
      extend self
      extend Helper

      def format(node, indent:, source:)
        "'#{node.value}'".then(&and_indent(indent))
      end
    end

    module Literal
      extend self
      extend Helper

      def format(node, indent:, source:)
        case node.value
        in Integer | Float then node.value.to_s
        in TrueClass       then "True"
        in FalseClass      then "False"
        in String          then node.value.inspect
        end
          .then(&and_indent(indent))
      end
    end

    module Placeholder
      extend self
      extend Helper

      def format(node, indent:, source:)
        "_".then(&and_indent(indent))
      end
    end

    module RecordAccessSugar
      extend self
      extend Helper

      def format(node, indent:, source:)
        ".#{node.field_key}".then(&and_indent(indent))
      end
    end

    module RecordUpdateSugar
      extend self
      extend Helper

      def format(node, indent:, source:)
        ".#{node.field_key}=".then(&and_indent(indent))
      end
    end

    module Grouping
      extend self
      extend Helper

      def format(node, indent:, source:)
        "(#{format_node(node.expression, source:)})".then(&and_indent(indent))
      end
    end

    module FunctionDeclarationParam
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{node.name}: #{format_type(node.type)}"
      end
    end

    module InteropFunction
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{node.name} : #{format_type(node.type)}"
      end
    end

    module InterfaceFunctionDecl
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{node.name} : #{format_type(node.type)}".then(&and_indent(indent))
      end
    end
  end
end
