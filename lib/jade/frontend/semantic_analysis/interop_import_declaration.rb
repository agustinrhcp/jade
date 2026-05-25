module Jade
  module Frontend
    module SemanticAnalysis
      module InteropImportDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::InteropImportDeclaration(functions:)

          functions_with_symbols = functions.map do |fn|
            entry
              .lookup_value(fn.name)
              .then { fn.with(symbol: it) }
          end

          type_errors = functions_with_symbols
            .flat_map { validate_type_symbol(it.symbol, registry, entry) }

          task_errors = functions_with_symbols
            .flat_map { |fn| task_shape_errors(fn, entry) }

          Result
            .init(node.with(functions: functions_with_symbols), scope)
            .add_errors(type_errors + task_errors)
        end

        private

        def task_shape_errors(fn, entry)
          unless task_type?(fn.symbol.return_type)
            Error::NonTaskPort
              .new(entry.name, fn.range, fn_name: fn.name)
              .then { return [it] }
          end

          fn.symbol.return_type => Symbol::TypeApplication(args: [ok_arm, err_arm])

          [ok_arm, err_arm]
            .any? { contains_task?(it) }
            .then { it ? [Error::NestedTaskPort.new(entry.name, fn.range, fn_name: fn.name)] : [] }
        end

        def task_type?(symbol)
          case symbol
          in Symbol::TypeApplication(constructor: Symbol::TypeRef['Task', 'Task'])
            true

          else
            false
          end
        end

        def contains_task?(symbol)
          case symbol
          in Symbol::TypeApplication(constructor: Symbol::TypeRef['Task', 'Task'])
             true

          in Symbol::TypeApplication(args:)
            args.any? { contains_task?(it) }

          else
            false
          end
        end
      end
    end
  end
end
