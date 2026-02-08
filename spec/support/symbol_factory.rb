module Jade
  module SymbolFactory
    def type_ref_sym(module_name, name)
      Symbol::TypeRef[module_name, name]
    end

    def type_sym(module_name, name)
      Symbol::TypeApplication.new(
        constructor: type_ref_sym(module_name, name),
        args: []
      )
    end

    def fn_sym(module_name, name)
      Symbol::Function.new(
        module_name: module_name,
        name: name,
        params: {},
        return_type: nil,
      )
    end

    def var_sym(name)
      Symbol.var(name, nil)
    end
  end
end
