require 'jade/codegen/helpers'

module Jade
  module Frontend
    module Desugaring
      module Placeholder
        extend self
        extend Codegen::Helpers

        def lift(call)
          return call unless call.args.any?(AST::Placeholder)

          filled_args, names = call
            .args
            .reduce([[], []]) do |(args, names), arg|
              case arg
              in AST::Placeholder
                param_synthetic_name(names.size)
                  .then { [args + [AST::VariableReference[it, nil]], names + [it]] }

              else
                [args + [arg], names]
              end
          end

          names
            .reverse
            .reduce(call.with(args: filled_args)) do |body, name|
              AST::Lambda[
                [AST::Pattern::Binding[name, nil]],
                AST::Body[[body], nil],
                call.range,
              ]
            end
        end
      end
    end
  end
end
