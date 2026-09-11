module Jade
  module Repl
    # An input compiled as a module of its own. The header is generated:
    # the module's name, what it exposes, and every import it sees, merged
    # per module. The body is the input's own text, with its imports blanked
    # out, since the header carries them, and `it = ` in front of a trailing
    # expression. Both edits keep byte offsets, so a diagnostic maps back.
    #
    # Subclassed rather than `Cell = Data.define(...) do ... end` so the
    # constant stays on the class.
    class Cell < Data.define(:module_name, :uri, :header, :body, :insertion, :input)
      IT = 'it = '.freeze

      def self.build(input, scope:, space:, number:)
        "#{space}/c#{number}.jd".then do |uri|
          name = Source.new(uri:, text: '').to_module_name
          insertion = input.expression&.range&.begin

          new(
            module_name: name,
            uri:,
            header: header(name, exposes(input), scope),
            body: body(input, insertion),
            insertion:,
            input:,
          )
        end
      end

      def self.header(name, exposes, scope)
        [
          "module #{name} exposing (#{exposing(exposes)})",
          '',
          *scope.header_imports,
        ]
          .join("\n")
          .then { "#{it}\n\n" }
      end

      def self.exposing(exposes)
        exposes
          .map { |(kind, name, expand)| kind == :type && expand ? "#{name}(..)" : name }
          .uniq
          .then { it.empty? ? '..' : it.join(', ') }
      end

      def self.exposes(input)
        input
          .statements
          .flat_map { exposed_by(it) }
          .reject { |(_, name)| name.start_with?('(') }
      end

      def self.exposed_by(node)
        case node
        in AST::FunctionDeclaration(name:) then [[:value, name]]
        in AST::Assign(pattern: AST::Pattern::Binding(name:)) then [[:value, name]]
        in AST::TypeDeclaration(name:) then [[:type, name, true]]
        in AST::StructDeclaration(name:) then [[:type, name, true]]
        in AST::TypeAliasDeclaration(name:) then [[:type, name, false]]

        in AST::InterfaceDeclaration(name:, functions:)
          [[:type, name, false], *functions.map { [:value, it.name] }]

        in AST::InteropImportDeclaration(functions:)
          functions.map { [:value, it.name] }

        in AST::Implementation | AST::ImportDeclaration then []
        else [[:value, 'it']]
        end
      end

      def self.body(input, insertion)
        input
          .imports
          .reduce(input.source.text.b) { |text, node| blank(text, extent(input, node)) }
          .then { insertion ? it.byteslice(0, insertion) + IT.b + it.byteslice(insertion..) : it }
          .force_encoding(Encoding::UTF_8)
      end

      # An import's own range stops at its module name, so it runs to
      # wherever the next statement starts.
      def self.extent(input, node)
        input
          .statements
          .map { it.range.begin }
          .select { it > node.range.begin }
          .min
          .then { node.range.begin...(it || input.source.text.bytesize) }
      end

      def self.blank(text, range)
        text.dup.tap { it[range] = it[range].gsub(/[^\n]/, ' ') }
      end

      private_class_method :header, :exposing, :exposed_by, :body, :extent, :blank

      def text
        header + body
      end

      def exposes
        Cell.exposes(input)
      end

      def bindings
        input
          .statements
          .filter_map do |node|
            case node
            in AST::Assign(pattern: AST::Pattern::Binding(name:)) then name
            else Input.expression?(node) ? 'it' : nil
            end
          end
      end

      def imports_only?
        input.statements.all? { it.is_a?(AST::ImportDeclaration) }
      end

      def implements?
        input.statements.any? { it.is_a?(AST::Implementation) }
      end

      def remap(diagnostics)
        diagnostics.with(items: diagnostics.items.map { remap_diagnostic(it) })
      end

      private

      def remap_diagnostic(diagnostic)
        diagnostic.with(
          primary: diagnostic.primary&.then { remap_label(it) },
          secondary: diagnostic.secondary.map { remap_label(it) }.select(&:source),
        )
      end

      # A span in the generated header has no text in the input to point
      # at; the message stands alone.
      def remap_label(label)
        return label unless label.source&.uri == uri

        [label.span.begin, label.span.end]
          .map { offset(it) }
          .then do |(from, to)|
            from && to ?
              label.with(source: input.source, span: from...to) :
              label.with(source: nil)
          end
      end

      def offset(position)
        (position - header.bytesize).then do |at|
          next nil if at.negative?
          next at if insertion.nil? || at <= insertion

          [at - IT.bytesize, insertion].max
        end
      end
    end
  end
end
