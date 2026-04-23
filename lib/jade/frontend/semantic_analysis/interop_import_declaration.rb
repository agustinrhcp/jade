module Jade
  module Frontend
    module SemanticAnalysis
      module InteropImportDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::InteropImportDeclaration(functions:)

          type_errors = functions
            .flat_map { validate_type_symbol(it.symbol, registry) }

          task_errors = functions
            .filter_map do |fn|
              unless task_return_type?(fn.symbol)
                Error::NonTaskPort.new(entry.name, fn.range, fn_name: fn.name)
              end
            end

          Result[scope, type_errors + task_errors]
        end

        private

        def task_return_type?(symbol)
          case symbol.return_type
          in Symbol::TypeApplication(constructor: Symbol::TypeRef['Task', 'Task'])
            true

          else
            false
          end
        end
      end
    end
  end
end
