require 'jade/symbol/base'
require 'jade/symbol/parser'

require 'jade/symbol/anonymous_record'
require 'jade/symbol/constructor'
require 'jade/symbol/derived_function'
require 'jade/symbol/function'
require 'jade/symbol/function_type'
require 'jade/symbol/implementation'
require 'jade/symbol/implementation_template'
require 'jade/symbol/interface'
require 'jade/symbol/interface_function'
require 'jade/symbol/interop_function'
require 'jade/symbol/lambda'
require 'jade/symbol/record_type'
require 'jade/symbol/stdlib_function'
require 'jade/symbol/stdlib_implementation'
require 'jade/symbol/struct'
require 'jade/symbol/type_application'
require 'jade/symbol/partial_application'
require 'jade/symbol/type_param'
require 'jade/symbol/type_ref'
require 'jade/symbol/union'
require 'jade/symbol/variant'
require 'jade/symbol/value_ref'
require 'jade/symbol/variable'

module Jade
  module Symbol
    extend self

    def module_name(qualified_name)
      *module_parts, _ = qualified_name
      module_parts.join('.')
    end

    def unqualified_name(qualified_name)
      qualified_name.split('.').last
    end

    def anonymous_record(fields, row_var = nil)
      fail('fields is expected to be an array') unless fields.is_a?(Array)

      AnonymousRecord[fields, row_var]
    end

    def record_type(fields, row_var)
      fail('fields is expected to be a hash') unless fields.is_a?(Hash)

      RecordType[fields, row_var]
    end

    def union(name, type_params, variants, span)
      Union[nil, name, type_params, variants.map(&:to_ref), span]
    end

    def variant(name, args, union, span)
      Variant[nil, name, args, union, span]
    end

    def constructor(name, args, parent, span)
      Constructor[nil, name, args, parent, span]
    end

    def predeclared_constructor(name, span)
      Constructor[nil, name, [], nil, span]
    end

    def lambda(arity)
      Lambda[arity]
    end

    def type_ref(module_name, name)
      TypeRef[module_name, name]
    end

    def type_ref_from_qualified_name(q_name)
      *qualified_parts, name = q_name.split('.')
      TypeRef[qualified_parts.join('.'), name]
    end

    def value_ref(module_name, name)
      ValueRef[module_name, name]
    end

    def var(name, span)
      Variable[name, span]
    end

    def param(name, span)
      Param[name, span]
    end

    def predeclared_function(name)
      Function[nil, name, nil, nil]
    end

    def function(name, params, return_type)
      Function[nil, name, params, return_type]
    end

    def function_type(params, return_type)
      FunctionType[params, return_type]
    end

    def stdlib_function(name, params, return_type, codegen, constraints: [])
      StdlibFunction[nil, name, params, return_type, codegen, constraints]
    end

    def predeclared_interop_function(name)
      InteropFunction[nil, name, [], nil, nil, [], nil]
    end

    def interop_function(name, params, return_type, interop_module_name, constraints: [])
      InteropFunction[nil, name, params, return_type, interop_module_name, constraints, nil]
    end

    def type_application(constructor, args, span)
      TypeApplication[constructor, args, span]
    end

    def partial_application(constructor, args, span)
      PartialApplication[constructor, args, span]
    end

    def predeclared_struct(name, type_params, span)
      Struct[nil, name, type_params, nil, span]
    end

    def interface(name, type_var, functions, default, span)
      Interface[nil, name, type_var, functions, default, span]
    end

    def interface_function(name, inteface, params, return_type, span)
      InterfaceFunction[nil, name, inteface, params, return_type, span]
    end

    def implementation(
      interface,
      type,
      type_params,
      constraints,
      functions,
      deps,
      span,
      extends: []
    )
      Implementation[
        nil,
        interface,
        type,
        type_params,
        constraints,
        functions,
        deps,
        extends,
        span,
      ]
    end

    def parse(annotation)
      Lexer
        .tokenize(Source.new(uri: nil, text: annotation))
        .then { Parser.parse(it) }
    end
  end
end
