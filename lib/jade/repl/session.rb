module Jade
  module Repl
    Accepted = Data.define(:session, :lines)
    Rejected = Data.define(:diagnostics)
    Raised = Data.define(:error)
    Line = Data.define(:text, :type)
    Typed = Data.define(:type, :constraints)

    # Everything accepted so far. An input that fails anywhere leaves the
    # session as it was, so what a session holds always compiles.
    Session = Data.define(:host, :scope, :overlays, :cells, :number) do
      def self.start(host)
        new(host:, scope: Scope.empty, overlays: {}, cells: ::Set[], number: 0)
      end

      def submit(text)
        case Input.parse(text)
        in Err(diagnostics) then Rejected[diagnostics]
        in Ok(input) if input.statements.empty? then Accepted[self, []]
        in Ok(input) then evaluate(input)
        end
      end

      def type_of(text)
        case Input.parse(text)
        in Err(diagnostics)
          Rejected[diagnostics]

        in Ok(input) if input.statements.size == 1 && input.expression
          compile(input, scope) => [cell, compiled]

          case compiled
          in Err(diagnostics) then Rejected[cell.remap(diagnostics)]
          in Ok(registry) then Accepted[self, [type_line(registry, cell, text.strip)]]
          end

        in Ok(_)
          Rejected[complaint('`:t` takes one expression')]
        end
      end

      def names
        scope.names
      end

      private

      def evaluate(input)
        next_scope = input.imports.reduce(scope) { |acc, node| acc.import(node) }
        compile(input, next_scope) => [cell, compiled]

        case compiled
        in Err(diagnostics) then Rejected[cell.remap(diagnostics)]
        in Ok(_) if cell.imports_only? then Accepted[with(scope: next_scope), []]
        in Ok(registry) then run(cell, registry, next_scope)
        end
      end

      def compile(input, visible)
        Cell
          .build(input, scope: visible, space: host.space, number: number + 1)
          .then do |cell|
            host
              .compile(overlays.merge(cell.uri => cell.text), cells + [cell.module_name], cell.uri)
              .then { [cell, it] }
          end
      end

      def run(cell, registry, next_scope)
        case host.run(registry, cell, forced(cell, registry))
        in Err(error) then Raised[error]
        in Ok(values) then Accepted[accept(cell, next_scope), lines(cell, registry, values)]
        end
      end

      def accept(cell, next_scope)
        with(
          scope: next_scope.provide(cell.module_name, cell.exposes, instances: cell.implements?),
          overlays: overlays.merge(cell.uri => cell.text),
          cells: cells + [cell.module_name],
          number: number + 1,
        )
      end

      # A value that needs a dictionary is still a function of it; there is
      # nothing to force until a caller picks the instance.
      def forced(cell, registry)
        cell
          .bindings
          .map { [it, typed(registry, cell, it)] }
          .reject { |(_, typed)| needs_dictionary?(typed) }
          .to_h { |(name, typed)| [name, name == 'it' && task?(typed.type.return_type)] }
      end

      def lines(cell, registry, values)
        cell
          .input
          .statements
          .flat_map { line(it, cell, registry, values) }
      end

      def line(node, cell, registry, values)
        case node
        in AST::FunctionDeclaration(name:)
          [signature_line(registry, cell, name)]

        in AST::Assign(pattern: AST::Pattern::Binding(name:))
          [value_line(registry, cell, values, name)]

        in AST::TypeDeclaration(name:) then [Line["type #{name}", nil]]
        in AST::StructDeclaration(name:) then [Line["struct #{name}", nil]]
        in AST::TypeAliasDeclaration(name:) then [Line["type alias #{name}", nil]]
        in AST::InterfaceDeclaration(name:) then [Line["interface #{name}", nil]]

        in AST::Implementation(interface:, applied_type:)
          [Line["implements #{interface}(#{cell.input.slice(applied_type.range)})", nil]]

        in AST::InteropImportDeclaration(functions:)
          functions.map { signature_line(registry, cell, it.name) }

        in AST::ImportDeclaration
          []

        else
          [value_line(registry, cell, values, 'it')]
        end
      end

      def signature_line(registry, cell, name)
        typed(registry, cell, name)
          .then { Line[name, Signature.describe(it.type, it.constraints)] }
      end

      def value_line(registry, cell, values, name)
        typed(registry, cell, name).then do |typed|
          shown = shown_type(typed.type.return_type, name)

          Line[
            value_text(values, name, shown),
            Signature.describe(shown, typed.constraints),
          ]
        end
      end

      def type_line(registry, cell, text)
        typed(registry, cell, 'it')
          .then { Line[text, Signature.describe(it.type.return_type, it.constraints)] }
      end

      def value_text(values, name, type)
        case [values.key?(name), type]
        in [false, _] then name
        in [true, Type::Function] then name == 'it' ? '<function>' : name

        in [true, _]
          Printer
            .render(values.fetch(name), type)
            .then { name == 'it' ? it : "#{name} = #{it}" }
        end
      end

      def shown_type(type, name)
        return type unless name == 'it' && task?(type)

        type => Type::Application(args:)
        Type.constructor('Result.Result').apply(args)
      end

      def task?(type)
        type in Type::Application(constructor: Type::Constructor(name: 'Task.Task'))
      end

      def needs_dictionary?(typed)
        typed.constraints.any? { it.type.is_a?(Type::Var) }
      end

      def typed(registry, cell, name)
        registry.get(cell.module_name).env.then do |env|
          env
            .bindings
            .fetch("#{cell.module_name}.#{name}")
            .then do |binding|
              Typed[
                env.substitution.apply(binding.type),
                binding.constraints.map { env.substitution.apply(it) },
              ]
            end
        end
      end

      def complaint(message)
        Diagnostics::List
          .empty
          .add(Diagnostics::Diagnostic.error(message, primary: nil))
      end
    end
  end
end
