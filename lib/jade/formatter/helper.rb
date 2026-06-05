module Jade
  module Formatter
    # Mixin for per-node formatter modules. Provides:
    #   - INDENT, LINE_LIMIT constants
    #   - `format_node(node, indent:, source:)` — top-level dispatcher
    #     that prepends leading comments and appends a trailing one.
    #   - `and_indent(n)` — prefixes every line of a string with N levels of
    #     indent, leaving blank lines untouched.
    #   - `too_long?(line, indent)` — width check against LINE_LIMIT.
    #   - `format_delimited(...)` — the open/items/close pattern used by
    #     Tuple, List, and a few callers.
    #   - `format_pattern`, `format_type`, `format_exposing` — sibling
    #     walks delegated to their own modules.
    module Helper
      def format_node(node, indent: 0, source: nil)
        leading  = format_leading_comments(node, indent)
        trailing = format_trailing_comment(node)

        dispatch_for(node)
          .format(node, indent:, source:)
          .then { leading + it + trailing }
      end

      def dispatch_for(node)
        case node
        in AST::Module                       then ModuleNode
        in AST::Body                         then Body
        in AST::FunctionDeclaration          then FunctionDeclaration
        in AST::FunctionDeclarationParam     then FunctionDeclarationParam
        in AST::TypeDeclaration              then TypeDeclaration
        in AST::VariantDeclaration           then VariantDeclaration
        in AST::StructDeclaration            then StructDeclaration
        in AST::TypeAliasDeclaration         then TypeAliasDeclaration
        in AST::ImportDeclaration            then ImportDeclaration
        in AST::InteropImportDeclaration     then InteropImportDeclaration
        in AST::InteropFunction              then InteropFunction
        in AST::InterfaceDeclaration         then InterfaceDeclaration
        in AST::InterfaceFunctionDecl        then InterfaceFunctionDecl
        in AST::Assign                       then Assign
        in AST::Bind                         then Bind
        in AST::Implementation               then Implementation
        in AST::ImplementationFunction       then ImplementationFunction
        in AST::IfThenElse                   then IfThenElse
        in AST::CaseOf                       then CaseOf
        in AST::CaseOfBranch                 then CaseOfBranch
        in AST::Lambda                       then Lambda
        in AST::InfixApplication             then InfixApplication
        in AST::FunctionCall                 then FunctionCall
        in AST::KeyedCall                    then KeyedCall
        in AST::Placeholder                  then Placeholder
        in AST::MemberAccess                 then MemberAccess
        in AST::QualifiedAccess              then QualifiedAccess
        in AST::RecordAccess                 then RecordAccess
        in AST::RecordAccessSugar            then RecordAccessSugar
        in AST::RecordUpdateSugar            then RecordUpdateSugar
        in AST::Grouping                     then Grouping
        in AST::Tuple                        then Tuple
        in AST::List                         then List
        in AST::RecordLiteral                then RecordLiteral
        in AST::RecordUpdate                 then RecordUpdate
        in AST::VariableReference            then VariableReference
        in AST::ConstructorReference         then ConstructorReference
        in AST::CharLiteral                  then CharLiteral
        in AST::Literal                      then Literal
        end
      end

      def and_indent(indent)
        ->(str) {
          prefix = INDENT * indent
          str.lines.map { |line| line == "\n" ? line : "#{prefix}#{line}" }.join
        }
      end

      def too_long?(line, indent)
        (INDENT * indent).length + line.length > LINE_LIMIT
      end

      def format_leading_comments(node, indent)
        return "" if node.leading_comments.empty?

        node.leading_comments
          .map { |tok| tok.value.then(&and_indent(indent)) }
          .join("\n")
          .then { it + "\n" }
      end

      def format_trailing_comment(node)
        return "" if node.trailing_comments.empty?

        " #{node.trailing_comments.first.value}"
      end

      # Generic open/sep/close formatter shared by Tuple and List. Inline
      # when it fits and no trailing-comma hint; multi-line otherwise.
      def format_delimited(strs, open, close, trailing_comma, indent)
        inline = "#{open}#{strs.join(', ')}#{close}"
        if trailing_comma || too_long?(inline, indent)
          inner = strs.map { "#{it.then(&and_indent(indent + 1))}," }.join("\n")
          "#{INDENT * indent}#{open}\n#{inner}\n#{INDENT * indent}#{close}"
        else
          inline.then(&and_indent(indent))
        end
      end

      def format_pattern(node, source: nil)
        Pattern.format(node, source:)
      end

      def format_type(node)
        Type.format(node)
      end

      def format_type_atom(node)
        Type.format_atom(node)
      end

      def format_exposing(node, indent: 0)
        Exposing.format(node, indent:)
      end
    end
  end
end
