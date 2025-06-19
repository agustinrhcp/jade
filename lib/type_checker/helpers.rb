module TypeChecker
  module Helpers
    extend self

    def walk_with_context(list, initial_context)
      list.reduce(Ok[[[], initial_context]]) do |acc, item|
        acc
          .and_then do |(collected, context)|
            yield(item, context)
              .map do |(checked, new_context)|
                [collected + [checked], new_context]
              end
              .map_error { |e| [e, context] }
          end
          .on_err do |(errors, context)|
            yield(item, context)
              .map_error { |e| [errors + [e], context] }
              .and_then { Err[_1] }
          end
      end
        .map_error(&:first)
    end

    def check_many(nodes, context)
      walk_with_context(nodes, context) do |node, next_context|
        TypeChecker.check(node, next_context)
      end
    end
  end
end
