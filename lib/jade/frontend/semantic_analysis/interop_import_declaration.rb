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
            .flat_map { |fn| task_shape_errors(fn, registry, entry) }

          Result
            .init(node.with(functions: functions_with_symbols), scope)
            .add_errors(type_errors + task_errors)
        end

        private

        TASK = 'Task.Task'

        # Asked of the expanded type rather than the written symbol, so an
        # alias over a `Task` is a port return type and cannot smuggle a
        # nested one past the guard.
        def task_shape_errors(fn, registry, entry)
          return_type = expand(fn.symbol.return_type, registry)

          unless task_type?(return_type)
            Error::NonTaskPort
              .new(entry.name, fn.range, fn_name: fn.name)
              .then { return [it] }
          end

          return_type => Type::Application(args: [ok_arm, err_arm])

          [ok_arm, err_arm]
            .any? { contains_task?(it) }
            .then { it ? [Error::NestedTaskPort.new(entry.name, fn.range, fn_name: fn.name)] : [] }
        end

        def expand(symbol, registry)
          Type
            .from_symbol(symbol, registry, TypeChecking::VarGen.new)
            .first
        end

        def task_type?(type)
          type in Type::Application(constructor: Type::Constructor(name: TASK))
        end

        def contains_task?(type)
          case type
          in Type::Application(constructor: Type::Constructor(name: TASK))
            true

          in Type::Application(args:)
            args.any? { contains_task?(it) }

          in Type::Function(args:, return_type:)
            (args + [return_type]).any? { contains_task?(it) }

          in Type::AnonymousRecord(fields:)
            fields.values.any? { contains_task?(it) }

          else
            false
          end
        end
      end
    end
  end
end
