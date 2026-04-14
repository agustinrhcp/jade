require 'jade/codegen/helpers'

module Jade
  module Frontend
    module ForwardDeclaration
      module ImplementationFunction
        extend self

        def declare(impl_fn, entry, interface, type_name)
          impl_fn => AST::ImplementationFunction(name: fn_name, fn:)

          case fn
          in AST::Lambda(params: lambda_params)
            synth_name = Codegen::Helpers
              .impl_synthetic_name(interface, type_name, fn_name)

            stub_params, stub_return = [
              lambda_params.to_h { |p| [p.name, Symbol.var(p.name, nil)] },
              Symbol.var("r", nil),
            ]

            Symbol
              .function(synth_name, stub_params, stub_return)
              .then { [entry.define(it), Symbol.value_ref(entry.name, synth_name)] }
            

          in AST::VariableReference
            [
              entry,
              Symbol.value_ref(entry.name, fn.name),
            ]
          end
        end
      end
    end
  end
end
