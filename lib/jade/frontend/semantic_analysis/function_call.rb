module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionCall
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::FunctionCall(callee:, args:)

          analyze_many(args, registry, scope, entry) => { errors: args_errors }
          result = analyze_node(callee, registry, scope, entry).add_errors(args_errors)

          return result unless calling_a_constant?(callee, args, registry)

          result.add_errors([constant_not_callable(callee, entry)])
        end

        private

        def calling_a_constant?(callee, args, registry)
          return false unless args.empty?

          case callee_symbol(callee, registry)
          in Symbol::Function | Symbol::StdlibFunction => fn then fn.constant?
          in Symbol::Constructor(args: []) then true
          else false
          end
        end

        def callee_symbol(callee, registry)
          case callee.symbol
          in Symbol::ValueRef => ref then registry.lookup(ref)
          in symbol then symbol
          end
        end

        def constant_not_callable(callee, entry)
          Error::ConstantNotCallable.new(
            entry.name,
            callee.range,
            name: callee_display_name(callee),
          )
        end

        def callee_display_name(callee)
          case callee
          in AST::VariableReference(name:) then name
          in AST::ConstructorReference(name:) then name
          in AST::QualifiedAccess(target:, name:) then "#{target.name}.#{name.name}"
          end
        end
      end
    end
  end
end
