module Jade
  module SymbolFactory
    def type_ref_sym(module_name, name)
      Symbol::TypeRef[module_name, name]
    end

    def type_sym(module_name, name)
      Symbol::TypeApplication.new(
        constructor: type_ref_sym(module_name, name),
        args: [],
        span: nil,
      )
    end

    def fn_sym(module_name, name)
      Symbol::Function.new(
        module_name: module_name,
        name: name,
        params: {},
        return_type: nil,
        decl_span: nil,
      )
    end

    def struct_sym(module_name, name)
      Symbol::Struct.new(
        module_name: module_name,
        name: name,
        type_params: [],
        record_type: rec_type_sym,
        decl_span: nil,
      )
    end

    def rec_type_sym
      Symbol::RecordType.new({}, nil)
    end

    def var_sym(name)
      Symbol.var(name, nil)
    end
  end
end
