module Jade
  module Stdlib
    module Compiled
      def generate_entry(registry)
        return @entry if @entry

        source = Source[uri, code]

        source
          .then { Lexer.tokenize(it) }
          .then { Parsing.parse(it, entry: source.uri) } => Ok([ast, _comments])

        Registry
          .entry(source.to_module_name)
          .with(ast:)
          .with(source:)
          .then { resolve_imports(it) }
          .then do
            Frontend
              .run_entry(it, registry.add_module(it))
              .map { Codegen.generate_entry(it, registry) }
          end => Ok(entry)

          @entry = entry
      end

      def entry
        @entry ||= fail("entry not generated yet.")
      end

      # Compiled modules declare interfaces and impls in their Jade source,
      # not via the Intrinsics DSL. The lookup that scans `imports` for
      # Interface symbols (intrinsics.rb#implementation) never finds anything
      # here, but exposing an empty list keeps the call site uniform.
      def symbols
        []
      end

      def resolve_imports(entry)
        imports
          .reduce(entry) do |acc, stdlib|
            ImportEntry[stdlib.entry.name, stdlib.entry.name, stdlib.default_imports, stdlib.entry.exposes]
              .then { acc.import(it) }
          end
      end
    end
  end
end
