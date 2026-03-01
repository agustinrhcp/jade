module Jade
  module Stdlib
    module Compiled
      def generate_entry(registry)
        return @entry if @entry

        source = Source[uri, code]

        source
          .then { Lexer.tokenize(it) }
          .then { Parsing.parse(it) } => Ok(ast)

        @entry = Registry
          .entry(source.to_module_name)
          .with(ast:)
          .with(source:)
          .then { resolve_imports(it) }
          .then do
            Frontend::ForwardDeclaration
              .declare_entry(it, registry) => Ok(declared)
            declared
          end
      end

      def entry
        @entry ||= fail("entry not generated yet.")
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
