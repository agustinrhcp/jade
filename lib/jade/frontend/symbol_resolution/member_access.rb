module Jade
  module Frontend
    module SymbolResolution
      module MemberAccess
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::MemberAccess(target:, name:)

          qualified_names = collect_qualified_names(node)

          if qualified_names
            *path, access = qualified_names

            resolve_qualified_access(path, name, registry, current_entry)
              .then { node.with(symbol: it) }
              .then { Result[it, []] }

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

        def resolve_qualified_access(path, accessed, registry, current_entry)
          imported = current_entry.imports.find { it.alias == path.join('.') } || fail("Module #{path.join('.')} not found")
          registry.get(imported.module_name).exports[accessed.name] || fail('Symbol is not exposed')
        end
      end
    end
  end
end
