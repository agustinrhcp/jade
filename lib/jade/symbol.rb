module Jade
  module Symbol
    def self.module_name(qualified_name)
      *module_parts, _ = qualified_name
      module_parts.join('.')
    end

    def qualified_name
      [module_name, name].join('.')
    end

    def self.unqualified_name(qualified_name)
      qualified_name.split('.').last
    end

    def self.anonymous_record(fields)
      fail('fields is expected to be an array') unless fields.is_a?(Array)

      AnonymousRecord[fields, nil]
    end

    def self.record_type(fields, row_var)
      fail('fields is expected to be a hash') unless fields.is_a?(Hash)

      RecordType[fields, row_var]
    end

    def self.union(name, type_params, variants)
      Union[nil, name, type_params, variants.map(&:to_ref)]
    end

    def self.variant(name, args, union)
      Variant[nil, name, args, union]
    end

    def self.predeclared_variant(name)
      Variant[nil, name, [], nil]
    end

    def self.lambda(arity)
      Lambda[arity]
    end

    def self.type_ref(module_name, name)
      TypeRef[module_name, name]
    end

    def self.value_ref(module_name, name)
      ValueRef[module_name, name]
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

    def self.function_type(params, return_type)
      FunctionType[params, return_type]
    end

    def self.stdlib_function(name, params, return_type, codegen)
      StdlibFunction[nil, name, params, return_type, codegen]
    end

    def self.predeclared_interop_function(name)
      InteropFunction[nil, name, [], nil, nil, nil]
    end

    def self.interop_function(name, params, return_type, interop_module_name, expected_type)
      InteropFunction[nil, name, params, return_type, interop_module_name, expected_type]
    end

    def self.type_application(constructor, args)
      TypeApplication[constructor, args]
    end

    Union = Data.define(:module_name, :name, :type_params, :variants) do
      include Symbol

      def to_ref
        TypeRef[module_name, name]
      end

      def qualified_name
        [module_name, name].join('.')
      end
    end

    TypeRef = Data.define(:module_name, :name) do
      include Symbol

      def qualified_name
        [module_name, name].join('.')
      end

      def to_ref
        self
      end
    end

    Function = Data.define(:module_name, :name, :params, :return_type) do
      include Symbol

      def to_ref
        ValueRef[module_name, name]
      end
    end

    FunctionType = Data.define(:params, :return_type) do
      include Symbol
    end

    Lambda = Data.define(:arity) do
      include Symbol
    end

    Variant = Data.define(:module_name, :name, :args, :union) do
      include Symbol

      def to_ref
        ValueRef[module_name, name]
      end

      def qualified_name
        [module_name, name].join('.')
      end
    end

    StdlibFunction = Data.define(:module_name, :name, :params, :return_type, :codegen) do
      include Symbol

      def to_ref
        ValueRef[module_name, name]
      end
    end

    InteropFunction = Data.define(
      :module_name,
      :name,
      :params,
      :return_type,
      :interop_module_name,
      :expected_type
    ) do
      include Symbol

      def to_ref
        ValueRef[module_name, name]
      end
    end

    ValueRef = Data.define(:module_name, :name) do
      include Symbol

      def to_ref
        self
      end

      def qualified_name
        [module_name, name].join('.')
      end
    end

    Variable = Data.define(:name) do
      include Symbol
    end

    Param = Data.define(:name) do
      include Symbol
    end

    AnonymousRecord = Data.define(:fields, :row_var) do
      include Symbol
    end

    RecordType = Data.define(:fields, :row_var) do
      include Symbol
    end

    TypeApplication = Data.define(:constructor, :args) do
      include Symbol
    end
  end
end
