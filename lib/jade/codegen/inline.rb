module Jade
  module Codegen
    module Inline
      extend self
      extend Helpers

      def try_for(callee, args, dictionaries, registry)
        try_block_form(callee, args, registry)
          .then { return it if it }

        fn = resolve_inline_fn(callee, dictionaries, registry)
        return nil unless fn && fn.arity == args.size

        fn.call(*args.map { generate_node(it, registry) })
      end

      private

      # Native block form is 2-3× faster than `&lambda` because Ruby skips
      # the lambda-to-block conversion per call.
      def try_block_form(callee, args, registry)
        return nil unless args.last in AST::Lambda(params: lambda_params, body: lambda_body)
        return nil unless simple_lambda_params?(lambda_params)
        return nil unless resolve_callee_symbol(callee, registry) in Symbol::StdlibFunction(module_name:, name:)

        template = Inlines.block_for("#{module_name}.#{name}")
        return nil unless template

        template.call(
          *args[0...-1].map { generate_node(it, registry) },
          lambda_params.map { lambda_param_name(it) }.join(', '),
          generate_node(lambda_body, registry),
        )
      end

      def resolve_inline_fn(callee, dictionaries, registry)
        case resolve_callee_symbol(callee, registry)
        in Symbol::StdlibFunction(module_name:, name:)
          qualified = "#{module_name}.#{name}"
          Inlines.for(qualified) ||
            Inlines.comparison_for(qualified, dictionaries, registry) ||
            Inlines.neq_for(qualified, dictionaries, registry)

        in Symbol::InterfaceFunction(name: fn_name) if dictionaries&.first.is_a?(Symbol::Implementation)
          interface_impl_inline(dictionaries.first.functions[fn_name], registry)

        else
          nil
        end
      end

      def interface_impl_inline(entry, registry)
        return nil unless entry in Symbol::ValueRef
        return nil unless registry.lookup(entry) in Symbol::StdlibFunction(module_name:, name:)

        Inlines.for("#{module_name}.#{name}")
      end

      def simple_lambda_params?(params)
        params.all? { it.is_a?(AST::Pattern::Binding) || it.is_a?(AST::Pattern::Wildcard) }
      end

      def lambda_param_name(pattern)
        case pattern
        in AST::Pattern::Binding(name:) then name
        in AST::Pattern::Wildcard then '_'
        end
      end
    end
  end
end
