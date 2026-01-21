module Jade
  module Frontend
    module ForwardDeclaration
      module ImportDeclaration
        extend self

        # TODO: This does a lot, so It could just be import registration.
        #  everything else doesn't need the registry at all
        def shallow(ast, registry, entry)
          ast => AST::ImportDeclaration(module_name:, as:, exposing:)

          importing_module = registry.get(module_name)

          unless importing_module
            return [
              entry,
              [ModuleNotFound.new(entry, ast.range, name: module_name)],
            ]
          end

          exposing_to_symbol(exposing, entry, importing_module)
            .map { ImportEntry[module_name, as || module_name, it, importing_module.exposes] }
            .on_err { return Result[entry, it] } => Ok(import_entry)

          Result[entry.import(import_entry), []]
        end

        def deep(_, entry)
          Result[entry, []]
        end

        private

        def exposing_to_symbol(exposing, current_entry, importing_module)
          case exposing
          in AST::ExposeNone then Ok[[]]
          in AST::ExposeAll then Ok[importing_module.exposed]
          in AST::ExposeList(items:) then handle_exposing_list(items, current_entry, importing_module)
          end
        end

        def bad_import(current_entry, span, module_name, name)
          Err[Error::BadImport.new(current_entry.name, span, module_name:, name:)]
        end

        def handle_exposing_list(items, current_entry, importing_module)
          items
            .map do |item|
              case item
              in AST::ExposeValue(name:, range:)
                handle_exposing_value(name, range, current_entry, importing_module)

              in AST::ExposeType(name:, range:)
                handle_exposing_type(name, range, current_entry, importing_module)

              in AST::ExposeTypeExpand(name:, range:)
                handle_exposing_type(name, range, current_entry, importing_module)
                  .and_then do |type|
                    handling_exposing_type_expansion(
                      type, name, range, current_entry, importing_module
                    )
                  end
              end
            end
            .then { combine_results(it) }
            .map(&:flatten)
        end

        def handle_exposing_value(name, span, current_entry, importing_module)
          importing_module
            .exposed_value(name)
            .then do
              it ? Ok[it] : bad_import(current_entry, span, importing_module.name, name)
            end
        end

        def handle_exposing_type(name, span, current_entry, importing_module)
          importing_module
            .exposed_type(name)
            .then do
              it ? Ok[it] : bad_import(current_entry, span, importing_module.name, name)
            end
        end

        def handling_exposing_type_expansion(type, name, span, current_entry, importing_module)
          importing_module
            .exposed_type_variants(name)
            .then  do |variants|
              if variants
                Ok[variants + [type]]
              else
                Error::PrivateTypeExpansion
                  .new(current_entry.name, span, name:, module_name: importing_module.name)
                  .then { Err[it] }
              end
            end
        end

        def combine_results(results)
          oks, errs = results.partition(&:ok?)

          if errs.empty?
            oks
              .map { it => Ok(ok); ok }
              .then { Ok[it] }
          else
            errs
              .map { it => Err(err); err }
              .then { Err[it] }
          end
        end
      end
    end
  end
end
