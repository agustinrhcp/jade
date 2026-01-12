module Jade
  module Stdlib
    module Compiled
      def generate_entry(registry)
        return @entry if @entry

        source = Source[uri, code]

        source
          .then { Lexer.tokenize(it) }
          .then { Parser.parse(it) } => Ok(ast)

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
          .map(&:entry)
          .reduce(entry) do |acc, stdlib|
            stdlib
              .exposes
              .values
              .reduce(acc) do |acc2, sym|
                acc2.add_imported_symbol(sym)
              end
              .add_import(stdlib)
          end
      end
    end
  end
end
