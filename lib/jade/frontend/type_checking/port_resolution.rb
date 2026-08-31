require 'jade/type'
require 'jade/frontend/type_checking/constraints'
require 'jade/frontend/type_checking/var_gen'
require 'jade/frontend/type_checking/error/port_not_decodable'
require 'jade/frontend/type_checking/error/port_not_encodable'

module Jade
  module Frontend
    module TypeChecking
      # Resolves the instances each port needs to convert at the boundary:
      # Decode.Decodable for its ok/err arms, Encode.Encodable for its
      # arguments. Runs at the end of type-checking, when
      # registry.implementations is fully populated. The resolved
      # Symbol::Implementation (or the :pass sentinel for Decode.Value / Never)
      # is stamped onto each InteropFunction's `decoders` / `encoders` fields
      # so codegen can emit straight away.
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
          in Symbol::InteropFunction
            resolve_port(sym, entry, registry)

          else
            [sym, []]
          end
        end

        def resolve_port(interop_fn, entry, registry)
          ok_sym, err_sym = arm_symbols(interop_fn.return_type)

          # Single Type.from_symbol over the whole port so a var appearing in
          # more than one position gets the same Type::Var id. PortCodec relies
          # on those ids to build the call-site synthetic dict_env.
          Type
            .from_symbol(port_symbol(interop_fn), registry, VarGen.new)
            .first => Type::Function(args: param_types, return_type: Type::Application(args: [ok_type, err_type]))

          ok, ok_errors = resolve_arm(ok_sym, ok_type, interop_fn, :ok, entry, registry)
          err, err_errors = resolve_arm(err_sym, err_type, interop_fn, :err, entry, registry)
          encoders, param_errors = resolve_params(interop_fn, param_types, entry, registry)

          [
            interop_fn.with(decoders: { ok:, err: }, encoders:),
            ok_errors + err_errors + param_errors,
          ]
        end

        # The arms are only wanted for their spans. An alias over a `Task`
        # keeps its arms in another declaration, so there is no span here to
        # point at and the port's own return type is the best there is.
        def arm_symbols(return_type)
          case return_type
          in Symbol::TypeApplication(constructor: Symbol::TypeRef['Task', 'Task'], args: [ok, err])
            [ok, err]

          else
            [nil, nil]
          end
        end

        # Without the constraints the shared VarGen would still hand every
        # position its own var; `from_symbol` only ties them together through
        # the map it threads across params and return.
        def port_symbol(interop_fn)
          Symbol.function_type(interop_fn.params, interop_fn.return_type)
        end

        def resolve_params(interop_fn, param_types, entry, registry)
          interop_fn
            .params
            .zip(param_types)
            .each_with_index
            .map { |(sym, type), index| resolve_param(sym, type, interop_fn, index, entry, registry) }
            .then { |results| [results.map(&:first), results.flat_map(&:last)] }
        end

        def resolve_param(type_sym, type, interop_fn, index, entry, registry)
          return [Symbol::InteropFunction::PASS, []] if pass_through?(type)

          case type
          in Type::Var(name:)
            constraint_index_for(interop_fn, 'Encode.Encodable', name)
              .then { [Symbol::InteropFunction::Dict.new(constraint_index: it), []] }

          else
            Type
              .constraint('Encode.Encodable', type, nil)
              .then { Constraints.resolve(it, registry, entry.name) }
              .then { encoder_result(it, interop_fn, index, entry, type, span_of(type_sym, interop_fn)) }
          end
        end

        def resolve_arm(type_sym, type, interop_fn, arm, entry, registry)
          return [Symbol::InteropFunction::PASS, []] if pass_through?(type)

          case type
          in Type::Var(name:)
            constraint_index_for(interop_fn, 'Decode.Decodable', name)
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

        def constraint_index_for(interop_fn, interface, var_name)
          interop_fn
            .constraints
            .index { |iface, name| iface == interface && name == var_name }
            .tap { fail "no #{interface} constraint for #{var_name.inspect}" if it.nil? }
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

        def encoder_result(constraint_result, interop_fn, index, entry, type, span)
          case constraint_result
          in Ok[impl]
            [impl, []]

          in Err
            Error::PortNotEncodable
              .new(entry, span, port_name: interop_fn.name, position: index + 1, type:)
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

        # Asked of the expanded type, so an alias over `Never` or
        # `Decode.Value` passes through the same as the type it names.
        def pass_through?(type)
          case type
          in Type::Application(constructor: Type::Constructor(name: 'Basics.Never' | 'Decode.Value'))
            true

          else
            false
          end
        end
      end
    end
  end
end
