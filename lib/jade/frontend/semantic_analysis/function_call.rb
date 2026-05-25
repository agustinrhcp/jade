module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionCall
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::FunctionCall(callee:, args:)

          callee_r = analyze_node(callee, registry, scope, entry)
          args_r = analyze_in_parallel(args, registry, scope, entry)

          Result
            .combine(node, scope:, callee: callee_r, args: args_r)
            .add_errors(
              calling_a_constant?(callee_r.node, args_r.node, registry) ?
                [constant_not_callable(callee_r.node, entry)] :
                [],
            )
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
