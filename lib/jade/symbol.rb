module Jade
  module Symbol
    def self.module_name(qualified_name)
      *module_parts, _ = qualified_name
      module_parts.join('.')
    end

    def self.unqualified_name(qualified_name)
      qualified_name.split('.').last
    end

    def self.union(name)
      Type[nil, name]
    end

    def self.type_ref(qualified_name)
      TypeRef[qualified_name]
    end

    def self.var(name)
      Variable[name]
    end

    def self.param(name)
      Param[name]
    end

    def self.predeclared_function(name)
      Function[nil, name, nil, nil]
    end

    def self.function(name, params, return_type)
      Function[nil, name, params, return_type]
    end

    Type = Data.define(:module_name, :name) do
      include Symbol

      def to_ref
        [module_name, name].join('.')
          .then { TypeRef[it] }
      end
    end

    TypeRef = Data.define(:qualified_name) do
      include Symbol
    end

    Function = Data.define(:module_name, :name, :params, :return_type) do
      include Symbol

      def to_ref
        [module_name, name].join('.')
          .then { ValueRef[it] }
      end
    end

    ValueRef = Data.define(:qualified_name) do
      include Symbol
    end

    Variable = Data.define(:name) do
      include Symbol
    end

    Param = Data.define(:name) do
      include Symbol
    end
  end
end
