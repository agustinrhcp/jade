module Jade
  module Codegen
    module FunctionDeclaration
      extend self
      extend Helpers

      def generate_boundary_wrapper(node, registry)
        node => AST::FunctionDeclaration(name:, symbol:)

        entry = registry.get(symbol.module_name)
        return nil unless entry&.exposed_value(name)

        if !dict_constraints(symbol, registry).empty?
          return not_exposed_stub(symbol, 'polymorphic — no extractable witness for type variable')
        end

        fn_type = fn_type_for(symbol, registry)
        unless Codegen::Boundary.eligible?(fn_type, registry)
          return not_exposed_stub(symbol, ineligibility_reason(fn_type, registry))
        end

        args, return_type = Type.signature(fn_type)

        if task_return?(return_type)
          task_wrapper_pair(name, args, return_type, registry)
        else
          eligible_wrapper(name, args, return_type, registry)
        end
      end

      def generate(node, registry)
        node => AST::FunctionDeclaration(name:, params:, body:, symbol:)

        var_cs      = dict_constraints(symbol, registry)
        param_names = params.map { generate_node(it, registry) }
        dict_params = var_cs.each_index.map { dict_synthetic_name(it) }

        body_code = build_dict_env(var_cs)
          .then { Codegen.with_dict_env(it) { generate_node(body, registry) } }

        target = var_cs.empty? ? name : fn_impl_synthetic_name(name)

        (param_names + dict_params)
          .join(', ')
          .then { Pretty.lambda(it, body_code) }
          .then { Pretty.block("def #{target}", it) }
      end

      private

      def eligible_wrapper(name, args, return_type, registry)
        param_names = args.each_index.map { param_synthetic_name(it) }
        encoder     = Codegen::Boundary.encoder_for(return_type, registry)

        [
          *decode_arg_lines(args, param_names, registry),
          "#{encoder}.call(Internal.#{name}.call#{decoded_call_args(param_names)})",
        ]
          .join(Pretty.newline)
          .then { Pretty.block("def self.#{name}(#{param_names.join(', ')})", it) }
      end

      def task_wrapper_pair(name, args, task_return, registry)
        ok_enc, err_enc = Codegen::Boundary.task_arms(task_return, registry)
        param_names     = args.each_index.map { param_synthetic_name(it) }
        params_str      = param_names.join(', ')

        run_def  = task_run_def(name, params_str, args, param_names, ok_enc, err_enc, registry)
        bang_def = task_bang_def(name, params_str, param_names)

        [run_def, bang_def].join(Pretty.newline(2))
      end

      def task_run_def(name, params_str, args, param_names, ok_enc, err_enc, registry)
        [
          *decode_arg_lines(args, param_names, registry),
          "case Internal.#{name}.call#{decoded_call_args(param_names)}.run",
          "in Jade::Result::Ok[v]  then [\"ok\",  #{ok_enc}.call(v)]",
          "in Jade::Result::Err[e] then [\"err\", #{err_enc}.call(e)]",
          'end',
        ]
          .join(Pretty.newline)
          .then { Pretty.block("def self.#{name}(#{params_str})", it) }
      end

      def task_bang_def(name, params_str, param_names)
        [
          "case #{name}#{paren_or_empty(param_names)}",
          'in ["ok",  v] then v',
          'in ["err", e] then raise Jade::Interop::TaskError.new(e)',
          'end',
        ]
          .join(Pretty.newline)
          .then { Pretty.block("def self.#{name}!(#{params_str})", it) }
      end

      def task_return?(type)
        type in Type::Application(constructor: Type::Constructor(name: 'Task.Task'))
      end

      def decode_arg_lines(args, param_names, registry)
        args
          .zip(param_names)
          .each_with_index.map do |(arg_type, pname), i|
            Codegen::Boundary.decoder_for(arg_type, registry)
              .then { "#{decoded_name(i)} = Jade::Interop::Boundary.decode_or_raise(#{it}, #{pname})" }
          end
      end

      def decoded_call_args(param_names)
        param_names
          .each_index
          .map { decoded_name(it) }
          .then { paren_or_empty(it) }
      end

      def paren_or_empty(items)
        items.empty? ? '' : "(#{items.join(', ')})"
      end

      def not_exposed_stub(symbol, reason)
        "raise Jade::Interop::NotExposed.new(" \
          "module_name: #{to_qualified(symbol.module_name).inspect}, " \
          "function_name: #{symbol.name.to_sym.inspect}, " \
          "hint: #{reason.inspect})"
          .then { Pretty.block("def self.#{symbol.name}(*)", it) }
      end

      def ineligibility_reason(fn_type, registry)
        args, ret = Type.signature(fn_type)

        arg_ineligibility_reason(args, registry) ||
          return_ineligibility_reason(ret, registry) ||
          fail("unreachable: eligible? returned false but no specific reason found for #{fn_type}")
      end

      def arg_ineligibility_reason(args, registry)
        args.each_with_index do |arg, i|
          if Codegen::Boundary.decoder_for(arg, registry).nil?
            return "argument #{i + 1} of type #{arg} has no Decodable instance"
          end
        end

        nil
      end

      def return_ineligibility_reason(ret, registry)
        case ret
        in Type::Application(constructor: Type::Constructor(name: 'Task.Task'), args: [ok_t, err_t])
          if Codegen::Boundary.encoder_for(ok_t, registry).nil?
            "Task ok arm of type #{ok_t} has no Encodable instance"

          elsif Codegen::Boundary.encoder_for(err_t, registry).nil?
            "Task err arm of type #{err_t} has no Encodable instance"
          end

        else
          if Codegen::Boundary.encoder_for(ret, registry).nil?
            "return type #{ret} has no Encodable instance"
          end
        end
      end

      def decoded_name(index)
        "__d#{index}__"
      end

      def fn_type_for(symbol, registry)
        registry
          .get(symbol.module_name)
          .env
          .then { it.substitution.apply(it.bindings[symbol.qualified_name].type) }
      end

      def build_dict_env(var_cs)
        var_cs
          .each_with_index
          .reduce({}) do |env, (c, i)|
            env.merge([c.interface, c.type.id] => dict_synthetic_name(i))
          end
      end
    end
  end
end
