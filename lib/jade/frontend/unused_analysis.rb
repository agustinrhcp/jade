module Jade
  module Frontend
    # Emits a warning per module-private function that no reference in
    # the module's own usage_index touches. Runs after UsageAnalysis so
    # it can read the index. Never fails; only appends to diagnostics.
    #
    # Scope is intentionally narrow: only Symbol::Function for now. Other
    # kinds (Constructor, Variant, Union, Struct, InterfaceFunction) need
    # separate filter rules — e.g. variants are reachable via pattern
    # match, interface fns are dispatched, not directly called — and are
    # deferred.
    module UnusedAnalysis
      extend self

      def analyze(entry, _registry)
        entry
          .defined_values
          .values
          .select { unused?(it, entry) }
          .reduce(entry.diagnostics) { |list, sym| list.add(warning(sym, entry)) }
          .then { entry.with(diagnostics: it) }
      end

      private

      def unused?(symbol, entry)
        symbol.is_a?(Jade::Symbol::Function) &&
          symbol.decl_span &&
          !entry.exposed_value(symbol.name) &&
          !entry.usage_index.ever_referenced?(symbol)
      end

      def warning(symbol, entry)
        Diagnostics::Diagnostic.warning(
          "unused function `#{symbol.name}`",
          primary: Diagnostics::Label[entry.source, symbol.decl_span, 'never used'],
        )
      end
    end
  end
end
