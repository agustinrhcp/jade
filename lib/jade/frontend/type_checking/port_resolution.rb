require 'jade/type'
require 'jade/frontend/type_checking/constraints'
require 'jade/frontend/type_checking/var_gen'
require 'jade/frontend/type_checking/error/port_not_decodable'

module Jade
  module Frontend
    module TypeChecking
      # Resolves the Decode.Decodable instances each port needs for its ok/err
      # arms. Runs at the end of type-checking, when registry.implementations
      # is fully populated. The resolved Symbol::Implementation (or the :pass
      # sentinel for Decode.Value / Never) is stamped onto each
      # InteropFunction's `decoders` field so codegen can emit straight away.
      module PortResolution
        extend self

        def resolve(entry, registry)
          entry
            .defined_values
            .reduce([{}, []]) do |(values, errors), (name, sym)|
              new_sym, new_errors = resolve_value(sym, entry, registry)
              [
                values.merge(name => new_sym),
                errors + new_errors,
              ]
            end
            .then { |values, errors|
              errors.empty? \
                ? Ok[entry.with(defined_values: values)]
                : Err[errors]
            }
        end

        private

        def resolve_value(sym, entry, registry)
          case sym
          in Symbol::InteropFunction(return_type: Symbol::TypeApplication)
            resolve_port(sym, entry, registry)

          else
            [sym, []]
          end
        end

        def resolve_port(interop_fn, entry, registry)
          interop_fn.return_type => Symbol::TypeApplication(args: [ok_sym, err_sym])

          # Single Type.from_symbol on the whole return so a var that appears
          # in both arms gets the same Type::Var id. PortDecoder relies on
          # those ids to build the call-site synthetic dict_env.
          Type
            .from_symbol(interop_fn.return_type, registry, VarGen.new)
            .first => Type::Application(args: [ok_type, err_type])

          ok, ok_errors = resolve_arm(ok_sym, ok_type, interop_fn, :ok, entry, registry)
          err, err_errors = resolve_arm(err_sym, err_type, interop_fn, :err, entry, registry)

          [
            interop_fn.with(decoders: { ok:, err: }),
            ok_errors + err_errors,
          ]
        end

        def resolve_arm(type_sym, type, interop_fn, arm, entry, registry)
          return [Symbol::InteropFunction::PASS, []] if pass_through?(type_sym)

          case type
          in Type::Var(name:)
            constraint_index_for(interop_fn, name)
              .then { [Symbol::InteropFunction::Dict.new(constraint_index: it), []] }

          else
            # Concrete OR compound-with-free-var. Resolve succeeds with a
            # partial Implementation (marker deps for free vars) thanks to
            # the deriver fallback in decodable.rb.
            Type
              .constraint('Decode.Decodable', type, nil)
              .then { Constraints.resolve(it, registry, entry.name) }
              .then { decoder_result(it, interop_fn, arm, entry, type, span_of(type_sym, interop_fn)) }
          end
        end

        def constraint_index_for(interop_fn, var_name)
          interop_fn
            .constraints
            .index { |_iface, name| name == var_name }
            .tap { fail "no Decodable constraint for #{var_name.inspect}" if it.nil? }
        end

        def decoder_result(constraint_result, interop_fn, arm, entry, type, span)
          case constraint_result
          in Ok[impl]
            [impl, []]

          in Err
            Error::PortNotDecodable
              .new(entry, span, port_name: interop_fn.name, arm:, type:)
              .then { [nil, [it]] }
          end
        end

        def span_of(type_sym, interop_fn)
          case type_sym
          in Symbol::TypeApplication(span:) then span
          in Symbol::Variable(decl_span:) then decl_span
          else interop_fn.return_type.span
          end
        end

        def pass_through?(type_sym)
          case type_sym
          in Symbol::TypeApplication(constructor: Symbol::TypeRef(module_name:, name:))
            [module_name, name] in ['Basics', 'Never'] | ['Decode', 'Value']

          else
            false
          end
        end
      end
    end
  end
end
