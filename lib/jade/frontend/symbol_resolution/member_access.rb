module Jade
  module Frontend
    module SymbolResolution
      module MemberAccess
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::MemberAccess(target:)

          qualified_names = collect_qualified_names(node)

          if qualified_names
            *path, access = qualified_names

            case resolve_qualified_access(path, node, registry, current_entry)
            in Ok(symbol)
              node.with(symbol:)
                .then { Result[it, []] }

            in Err(error)
              Result[node, [error]]
            end

          else
            resolve_node(target)
              .map { node.with(target: it) }
          end
        end

        private

        def collect_qualified_names(node)
          case node
          when AST::ConstructorReference
            [node.name]
          when AST::MemberAccess
            collect_qualified_names(node.target) + [node.name.name]
          else
            nil
          end
        end

        def resolve_qualified_access(path, node, registry, current_entry)
          node => AST::MemberAccess(name:, target:)

          module_name = path.join('.')
          import = current_entry
            .imports
            .find { it.alias == module_name }

          if import.nil?
            Error::ModuleNotFound
              .new(current_entry.name, node.target.range, name: import)

          else
            # TODO: exposes is a list, not a hash. I could however
            #   make it into a hash
            case registry.get(module_name).exposed_value(name.name)
            in nil
              Error::ValueNotExposed
                .new(current_entry.name, name.range, module_name:, name: name.name)

            in symbol
              return Ok[symbol]
            end
          end
            .then do
              Error::VariableNotFound
                .new(
                  current_entry.name,
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
