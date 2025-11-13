module Jade
  module Symbol
    def self.union(name)
      Type[nil, name]
    end

    def self.type_ref(qualified_name)
      TypeRef[qualified_name]
    end

    def self.var(name)
      Variable[name]
    end

    Type = Data.define(:module_name, :name) do
      include Symbol
    end

    TypeRef = Data.define(:qualified_name) do
      include Symbol
    end

    Function = Data.define(:module_name, :name, :params, :return_type) do
      include Symbol
    end

    ValueRef = Data.define(:qualified_name) do
      include Symbol
    end

    Variable = Data.define(:name) do
      include Symbol
    end
  end
end
