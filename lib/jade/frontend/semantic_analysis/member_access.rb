module Jade
  module Frontend
    module SemanticAnalysis
      # Lowers a MemberAccess chain into either a QualifiedAccess
      # (when the prefix resolves to an imported module alias) or a
      # RecordAccess (when it's field access on a value expression).
      module MemberAccess
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::MemberAccess(target:)

          qualified_names = collect_qualified_names(node)

          if qualified_names
            *path, access = qualified_names

            case resolve_qualified_access(path, node, registry, entry)
            in Ok(symbol)
              new_node = AST::QualifiedAccess[*node.deconstruct].with(symbol:)
              Result[new_node, [], scope]

            in Err(error)
              Result[node, [error], scope]
            end

          else
            target_r = analyze_node(target, registry, scope, entry)
            new_node = AST::RecordAccess[*node.with(target: target_r.node).deconstruct]
            Result[new_node, target_r.errors, scope]
          end
        end

        private

        def collect_qualified_names(node)
          case node
          in AST::ConstructorReference
            [node.name]

          in AST::MemberAccess
            names = collect_qualified_names(node.target)
            names ? names + [node.name.name] : nil

          else
            nil
          end
        end

        def resolve_qualified_access(path, node, registry, entry)
          node => AST::MemberAccess(name:, target:)

          module_name = path.join('.')
          import = entry
            .imports
            .find { it.alias == module_name }

          if import.nil?
            Error::ModuleNotFound
              .new(entry.name, node.target.range, name: import)

          else
            case registry.get(import.module_name).exposed_value(name.name)
            in nil
              Error::ValueNotExposed
                .new(entry.name, name.range, module_name:, name: name.name)

            in symbol
              return Ok[symbol]
            end
          end
            .then do
              Error::VariableNotFound
                .new(
                  entry.name,
                  node.range,
                  name: [module_name, name.name].join('.'),
                  causes: [it],
                )
            end
            .then { Err[it] }
        end
      end
    end
  end
end
