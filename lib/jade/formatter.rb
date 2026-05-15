module Jade
  module Formatter
    extend self

    INDENT = "  "

    def format(node, comments:, source:, indent: 0)
      format_node(Frontend::CommentAttacher.attach(node, comments, source), indent:)
    end

    private

    def format_node(node, indent: 0)
      leading  = format_leading_comments(node, indent)
      trailing = format_trailing_comment(node)

      case node
      in AST::Module(name:, exposing:, body:)
        chunks = body.expressions
          .chunk_while { |a, b| (a in AST::ImportDeclaration) && (b in AST::ImportDeclaration) }
          .map { |group| group.map { format_node(it, indent:) }.join("\n") }

        (["module #{name} #{format_exposing(exposing)}"] + chunks).join("\n\n")

      in AST::Body(expressions:, dangling_comments:)
        if expressions.empty? && !dangling_comments.empty?
          dangling_comments
            .map { |tok| "#{INDENT * indent}#{tok.value}" }
            .join("\n")
        else
          expressions
            .chunk_while { |a, b| binding?(a) == binding?(b) }
            .map { |group| group.map { format_node(it, indent:) }.join("\n") }
            .join("\n\n")
        end

      # Declarations

      in AST::FunctionDeclaration(name:, params:, return_type:, body:)
        params_str =
          params
            .map { format_node(it) }
            .join(", ")

        [
          "def #{name}(#{params_str}) -> #{format_type(return_type)}".then(&and_indent(indent)),
          format_node(body, indent: indent + 1),
          "end".then(&and_indent(indent)),
        ]
          .join("\n")

      in AST::FunctionDeclarationParam(name:, type:)
        "#{name}: #{format_type(type)}"

      in AST::TypeDeclaration(name:, type_params:, variants:)
        params_str = type_params.empty? ? "" : "(#{type_params.map(&:name).join(', ')})"
        header = "type #{name}#{params_str}"
        variants_strs = variants.map { format_node(it) }
        inline = "#{header} = #{variants_strs.join(' | ')}"

        if variants.size == 1 || !too_long?(inline, indent)
          inline.then(&and_indent(indent))
        else
          inner = INDENT * (indent + 1)
          multi = variants_strs
            .map.with_index { |v, i| "#{inner}#{i == 0 ? '=' : '|'} #{v}" }
            .join("\n")

          "#{and_indent(indent).call(header)}\n#{multi}"
        end

      in AST::VariantDeclaration(name:, args:)
        case args
        in nil | []
          name
        in [AST::TypeRecord(fields:, row_var: nil)]
          fields
            .map { |k, v| "#{k}: #{format_type(v)}" }
            .join(', ')
            .then { "#{name}(#{it})" }
        else
          args
            .map { format_type(it) }
            .join(', ')
            .then { "#{name}(#{it})" }
        end

      in AST::StructDeclaration(name:, type_params:, record_type:)
        params_str = type_params.empty? ? "" : "(#{type_params.map(&:name).join(', ')})"
        header     = "struct #{name}#{params_str} ="

        record_type => AST::TypeRecord(fields:, row_var:)

        if fields.size > 1
          open_brace = row_var ? "{ #{row_var.name} |" : "{"
          fields_str = fields
            .map { |k, v| "#{k}: #{format_type(v)}".then(&and_indent(indent + 1)) }
            .join(",\n")

          and_indent(indent)
            .call("#{header} #{open_brace}")
            .then { "#{it}\n#{fields_str}\n#{INDENT * indent}}" }
          
        else
          "#{header} #{format_type(record_type)}".then(&and_indent(indent))
        end

      in AST::ImportDeclaration(module_name:, as:, exposing:)
        parts = ["import #{module_name}"]
        parts << "as #{as.as}" if as
        parts << format_exposing(exposing) unless exposing in AST::ExposeNone | nil

        parts
          .join(' ')
          .then(&and_indent(indent))

      in AST::InteropImportDeclaration(module: interop_module, functions:)
        funcs_str =
          functions
            .map { format_node(it).then(&and_indent(indent + 1)) }
            .join(",\n")

        "uses #{interop_module.name} with\n#{funcs_str}\nend"
          .then(&and_indent(indent))

      in AST::InteropFunction(name:, type:)
        "#{name} : #{format_type(type)}"

      # Variable binding (let-style)

      in AST::Assign(pattern:, expression:)
        "#{format_pattern(pattern)} = #{format_node(expression)}"
          .then(&and_indent(indent))

      in AST::Bind(pattern:, expression:)
        "#{format_pattern(pattern)} <- #{format_node(expression)}"
          .then(&and_indent(indent))

      in AST::Implementation(interface:, applied_type:, extends:, functions:)
        extends_str = extends.empty? ? "" : " extends #{extends.join(', ')}"
        fns_str     = functions
          .map { format_node(it, indent: indent + 1) }
          .join(",\n")
        header = "implements #{interface}(#{format_type(applied_type)})#{extends_str} with"

        [
          header.then(&and_indent(indent)),
          fns_str,
          "end".then(&and_indent(indent)),
        ]
          .join("\n")

      in AST::ImplementationFunction(name:, fn:)
        "#{name}: #{format_node(fn)}"
          .then(&and_indent(indent))

      # Expressions

      in AST::IfThenElse(condition:, if_branch:, else_branch:)
        [
          "if #{format_node(condition)} then".then(&and_indent(indent)),
          format_node(if_branch, indent: indent + 1),
          "else".then(&and_indent(indent)),
          format_node(else_branch, indent: indent + 1),
          "end".then(&and_indent(indent)),
        ]
          .join("\n")

      in AST::CaseOf(expression:, branches:)
        branches_str =
          branches
            .map { format_node(it, indent:) }
            .join("\n")

        [
          "case #{format_node(expression)}".then(&and_indent(indent)),
          branches_str,
          "end".then(&and_indent(indent)),
        ]
          .join("\n")

      in AST::CaseOfBranch(pattern:, body:)
        pat_str = format_pattern(pattern)

        block_expr = case body.expressions.first
                     in AST::CaseOf | AST::IfThenElse then true
                     else false
                     end

        single_expr = body.expressions.length == 1 &&
          body.leading_comments.empty? &&
          body.expressions.first.leading_comments.empty? &&
          !block_expr

        inline_body = single_expr ? format_node(body.expressions.first) : nil
        inline = "of #{pat_str} then #{inline_body}" if inline_body

        if inline && !inline_body.include?("\n") && !too_long?(inline, indent)
          inline.then(&and_indent(indent))
        else
          [
            "of #{pat_str} then".then(&and_indent(indent)),
            format_node(body, indent: indent + 1),
          ]
            .join("\n")
        end

      in AST::Lambda(params:, body:)
        params_str =
          params
            .map { format_pattern(it) }
            .join(', ')

        if inline_lambda_body?(body)
          "(#{params_str}) -> { #{format_node(body.expressions.first)} }"
            .then(&and_indent(indent))
        else
          [
            "(#{params_str}) -> {".then(&and_indent(indent)),
            format_node(body, indent: indent + 1),
            "}".then(&and_indent(indent)),
          ]
            .join("\n")
        end

      in AST::InfixApplication(left:, operator:, right:)
        if operator.value == '|>'
          chain = collect_pipe_chain(node)
          inline = chain.map { format_node(it) }.join(' |> ')

          if too_long?(inline, indent)
            indent_str = INDENT * indent
            head = format_node(chain.first, indent:)
            tail = chain[1..].map { "#{indent_str}|> #{format_node(it)}" }
            ([head] + tail).join("\n")
          else
            inline.then(&and_indent(indent))
          end
        else
          "#{format_node(left)} #{operator.value} #{format_node(right)}"
            .then(&and_indent(indent))
        end

      in AST::FunctionCall(callee:, args:, trailing_comma:)
        callee_str = format_node(callee)
        args_strs  = args.map { format_node(it) }
        inline     = "#{callee_str}(#{args_strs.join(', ')})"

        if trailing_comma || too_long?(inline, indent)
          inner = args_strs.map { "#{it.then(&and_indent(indent + 1))}," }.join("\n")
          "#{callee_str.then(&and_indent(indent))}(\n#{inner}\n#{INDENT * indent})"
        else
          inline.then(&and_indent(indent))
        end

      in AST::MemberAccess(target:, name:)
        "#{format_node(target)}.#{name.name}"
          .then(&and_indent(indent))

      in AST::QualifiedAccess(target:, name:)
        "#{format_node(target)}.#{name}"
          .then(&and_indent(indent))

      in AST::RecordAccess(target:, name:)
        "#{format_node(target)}.#{name.name}"
          .then(&and_indent(indent))

      in AST::RecordAccessSugar(field_key:)
        ".#{field_key}"
          .then(&and_indent(indent))

      in AST::RecordUpdateSugar(field_key:)
        ".#{field_key}="
          .then(&and_indent(indent))

      in AST::Grouping(expression:)
        "(#{format_node(expression)})"
          .then(&and_indent(indent))

      in AST::Tuple(items:, trailing_comma:)
        format_delimited(items.map { format_node(it) }, '(', ')', trailing_comma, indent)

      in AST::List(items:, trailing_comma:)
        format_delimited(items.map { format_node(it) }, '[', ']', trailing_comma, indent)

      in AST::RecordLiteral(fields:, trailing_comma:)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value)}" }
        inline     = "{ #{field_strs.join(', ')} }"

        if trailing_comma || too_long?(inline, indent)
          inner = field_strs.map { "#{it.then(&and_indent(indent + 1))}," }.join("\n")
          "#{INDENT * indent}{\n#{inner}\n#{INDENT * indent}}"
        else
          inline.then(&and_indent(indent))
        end

      in AST::RecordUpdate(base:, fields:, trailing_comma:)
        base_str   = format_node(base)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value)}" }
        inline     = "{ #{base_str} | #{field_strs.join(', ')} }"

        if trailing_comma || too_long?(inline, indent)
          inner = field_strs.map { "#{it.then(&and_indent(indent + 1))}," }.join("\n")
          "#{INDENT * indent}{ #{base_str} |\n#{inner}\n#{INDENT * indent}}"
        else
          inline.then(&and_indent(indent))
        end

      in AST::VariableReference(name:)
        name
          .then(&and_indent(indent))

      in AST::ConstructorReference(name:)
        name
          .then(&and_indent(indent))

      in AST::CharLiteral(value:)
        "'#{value}'"
          .then(&and_indent(indent))

      in AST::Literal(value:)
        case value
        in Integer | Float  then value.to_s
        in TrueClass        then "True"
        in FalseClass       then "False"
        in String           then value.inspect
        end
          .then(&and_indent(indent))
      end
        .then { leading + it + trailing }
    end

    def binding?(node)
      node.is_a?(AST::Assign) || node.is_a?(AST::Bind)
    end

    def collect_pipe_chain(node)
      case node
      in AST::InfixApplication(left:, operator: AST::InfixOperator(value: '|>'), right:)
        collect_pipe_chain(left) + [right]
      else
        [node]
      end
    end

    def and_indent(indent)
      ->(str) {
        prefix = INDENT * indent
        str.lines.map { |line| line == "\n" ? line : "#{prefix}#{line}" }.join
      }
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

    def format_type(node)
      case node
      in AST::TypeName(type:)
        type

      in AST::QualifiedTypeName(path:)
        path.join(".")

      in AST::TypeVar(type:)
        type

      in AST::TypeApplication(constructor:, args:)
        if args.empty?
          format_type(constructor)
        else
          args_str =
            args
              .map { format_type(it) }
              .join(', ')

          "#{format_type(constructor)}(#{args_str})"
        end

      in AST::TypeFunction(params:, return_type:)
        params_str =
          if params.empty?
            "()"
          else
            params
              .map { format_type(it) }
              .join(', ')
          end

        "#{params_str} -> #{format_type(return_type)}"

      in AST::TypeRecord(fields:, row_var:)
        fields_str =
          fields
            .map { |k, v| "#{k}: #{format_type(v)}" }
            .join(", ")

        row_prefix = row_var ? "#{row_var.name} | " : ""

        "{ #{row_prefix}#{fields_str} }"

      in AST::TypeTuple(items:)
        items_str =
          items
            .map { format_type(it) }
            .join(', ')

        "(#{items_str})"
      end
    end

    def format_pattern(node)
      case node
      in AST::Pattern::Wildcard
        "_"

      in AST::Pattern::Literal(literal:)
        format_node(literal)

      in AST::Pattern::Binding(name:)
        name

      in AST::Pattern::Constructor(constructor:, patterns:)
        name = format_node(constructor)

        if patterns.nil? || patterns.empty?
          name
        else
          patterns_str =
            patterns
              .map { format_pattern(it) }
              .join(', ')

          "#{name}(#{patterns_str})"
        end

      in AST::Pattern::Record(fields:)
        fields_str =
          fields
            .map { format_pattern(it) }
            .join(", ")

        "{ #{fields_str} }"

      in AST::Pattern::RecordField(name:, pattern: AST::Pattern::Binding(name: ^name))
        "#{name}:"

      in AST::Pattern::RecordField(name:, pattern:)
        "#{name}: #{format_pattern(pattern)}"

      in AST::Pattern::Tuple(patterns:)
        patterns_str =
          patterns
            .map { format_pattern(it) }
            .join(', ')

        "(#{patterns_str})"

      in AST::Pattern::List(patterns:, rest:)
        heads = patterns.map { format_pattern(it) }.join(', ')
        tail =
          case rest
          in AST::Pattern::Binding(name:) then " | #{name}"
          in AST::Pattern::Wildcard then " | _"
          in nil then ""
          end

        "[#{heads}#{tail}]"
      end
    end

    def format_exposing(node, indent: 0)
      case node
      in AST::ExposeAll
        "exposing (..)"

      in AST::ExposeNone | nil
        ""

      in AST::ExposeList(items:, trailing_comma:)
        item_strs = sort_exposing(items).map { format_expose_item(it) }
        inline    = "exposing (#{item_strs.join(', ')})"

        if trailing_comma || too_long?(inline, indent)
          inner = item_strs.map { "#{INDENT * (indent + 1)}#{it}," }.join("\n")
          "exposing (\n#{inner}\n#{INDENT * indent})"
        else
          inline
        end
      end
    end

    def sort_exposing(items)
      items.sort_by do |item|
        case item
        in AST::ExposeType | AST::ExposeTypeExpand then [0, item.name]
        in AST::ExposeValue then [1, item.name]
        end
      end
    end

    LINE_LIMIT = 100

    INLINE_LAMBDA_BODY = [
      AST::Literal, AST::CharLiteral, AST::VariableReference, AST::ConstructorReference,
      AST::FunctionCall, AST::RecordAccess, AST::InfixApplication, AST::RecordLiteral,
      AST::List, AST::Tuple, AST::Grouping, AST::RecordUpdate, AST::RecordUpdateSugar,
      AST::RecordAccessSugar,
    ].freeze

    def too_long?(line, indent)
      (INDENT * indent).length + line.length > LINE_LIMIT
    end

    def inline_lambda_body?(body)
      body.expressions.length == 1 &&
        INLINE_LAMBDA_BODY.any? { body.expressions.first.is_a?(it) }
    end

    def format_delimited(strs, open, close, trailing_comma, indent)
      inline = "#{open}#{strs.join(', ')}#{close}"
      if trailing_comma || too_long?(inline, indent)
        inner = strs.map { "#{it.then(&and_indent(indent + 1))}," }.join("\n")
        "#{INDENT * indent}#{open}\n#{inner}\n#{INDENT * indent}#{close}"
      else
        inline.then(&and_indent(indent))
      end
    end

    def format_expose_item(node)
      case node
      in AST::ExposeValue(name:)      then name
      in AST::ExposeType(name:)       then name
      in AST::ExposeTypeExpand(name:) then "#{name}(..)"
      in AST::ExposeAs(as:)           then as
      end
    end
  end
end
