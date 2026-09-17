module Jade
  module Repl
    # One submission at the prompt, parsed as a module body with no header:
    # declarations, imports, `name = expr` bindings, and at most one bare
    # expression, last, which is the value the prompt shows.
    module Input
      extend self

      Parsed = Data.define(:source, :statements) do
        def imports
          statements.select { it.is_a?(AST::ImportDeclaration) }
        end

        def expression
          statements.last&.then { Input.expression?(it) ? it : nil }
        end

        def slice(range)
          source.text.byteslice(range.begin, range.end - range.begin)
        end
      end

      DECLARATIONS = [
        AST::FunctionDeclaration,
        AST::TypeDeclaration,
        AST::TypeAliasDeclaration,
        AST::StructDeclaration,
        AST::InterfaceDeclaration,
        AST::Implementation,
        AST::InteropImportDeclaration,
      ].freeze

      OPENERS = %i[lparen lbrack lbrace].freeze
      CLOSERS = %i[rparen rbrack rbrace].freeze

      CONTINUATIONS = %i[
        arrow colon comma dot assign bind pipe pipe_forward pipe_backward
        plus minus star slash plusplus eq not_eq lt lte gt gte andand oror
        question coloncolon
      ].freeze

      def parse(text)
        Source.new(uri: 'repl', text:).then do |source|
          Lexer
            .tokenize(source)
            .then { Parsing.parse(it, source:, parser: Parsing.program_body) }
            .map_error { Diagnostics::List.empty.add(it.to_diagnostic(source:)) }
            .and_then { |(body, _)| check(source, body.expressions) }
        end
      end

      # Running out of input means more lines are coming. So do an open
      # bracket and a trailing operator, which the parser reports as an
      # unexpected token instead, having backtracked to the end of the last
      # complete statement.
      def complete?(text)
        Source.new(uri: 'repl', text:).then do |source|
          tokens = Lexer.tokenize(source).reject { it.type == :comment }

          next false if depth(tokens).positive?
          next false if CONTINUATIONS.include?(tokens.last&.type)

          Parsing
            .parse(tokens, source:, parser: Parsing.program_body)
            .then { !(it in Err(Parsing::EOFError)) }
        end
      end

      def expression?(node)
        [AST::Assign, AST::Bind, AST::ImportDeclaration, *DECLARATIONS]
          .none? { node.is_a?(it) }
      end

      private

      def check(source, nodes)
        nodes
          .each_with_index
          .filter_map { |node, i| problem(node, last: i == nodes.size - 1)&.then { [node, *it] } }
          .reduce(Diagnostics::List.empty) do |list, (node, message, label)|
            list.error(message, source:, span: node.range, label:)
          end
          .then { it.empty? ? Ok[Parsed[source, nodes]] : Err[it] }
      end

      def problem(node, last:)
        case node
        in AST::Bind
          ['`<-` does not work at the prompt yet', 'not supported here']

        in AST::Assign(pattern: AST::Pattern::Binding) | AST::ImportDeclaration
          nil

        in AST::Assign
          ['Only a name can be bound at the prompt, not a pattern', 'bind a name']

        else
          return nil if last || !expression?(node)

          [
            'Only the last statement of an input can be a bare expression',
            'bind it: `name = ...`',
          ]
        end
      end

      def depth(tokens)
        tokens.sum do |token|
          case token.type
          when *OPENERS then 1
          when *CLOSERS then -1
          else 0
          end
        end
      end
    end
  end
end
