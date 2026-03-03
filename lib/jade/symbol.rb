require 'jade/symbol/base'
require 'jade/symbol/parser'

require 'jade/symbol/anonymous_record'
require 'jade/symbol/function'
require 'jade/symbol/function_type'
require 'jade/symbol/implementation'
require 'jade/symbol/interface'
require 'jade/symbol/interface_function'
require 'jade/symbol/interop_function'
require 'jade/symbol/lambda'
require 'jade/symbol/record_type'
require 'jade/symbol/stdlib_function'
require 'jade/symbol/struct'
require 'jade/symbol/type_application'
require 'jade/symbol/type_param'
require 'jade/symbol/type_ref'
require 'jade/symbol/union'
require 'jade/symbol/value_ref'
require 'jade/symbol/variable'
require 'jade/symbol/variant'

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

    def predeclared_variant(name, span)
      Variant[nil, name, [], nil, span]
    end

    def lambda(arity)
      Lambda[arity]
    end

    def type_ref(module_name, name)
      TypeRef[module_name, name]
    end

    def value_ref(module_name, name)
      ValueRef[module_name, name]
    end

    def var(name, span)
      Variable[name, span]
    end

    def param(name)
      Param[name]
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

    def stdlib_function(name, params, return_type, codegen)
      StdlibFunction[nil, name, params, return_type, codegen]
    end

    def predeclared_interop_function(name)
      InteropFunction[nil, name, [], nil, nil, nil]
    end

    def interop_function(name, params, return_type, interop_module_name, expected_type)
      InteropFunction[nil, name, params, return_type, interop_module_name, expected_type]
    end

    def type_application(constructor, args, span)
      TypeApplication[constructor, args, span]
    end

    def predeclared_struct(name, type_params, span)
      Struct[nil, name, type_params, nil, span]
    end

    def interface(name, type_var, functions, span)
      Interface[nil, name, type_var, functions, span]
    end

    def interface_function(name, inteface, params, return_type, span)
      InterfaceFunction[nil, name, inteface, params, return_type, span]
    end

    def implementation(interface, type, functions, span)
      Implementation[nil, interface, type, functions, span]
    end

    def parse(annotation)
      Lexer
        .tokenize(Source.new(uri: nil, text: annotation))
        .then { Parser.parse(it) }
    end
  end
end
