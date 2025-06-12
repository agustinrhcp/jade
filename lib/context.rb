Context = Data.define(:value_scope, :type_scope, :parent) do
  def initialize(value_scope: ValueScope.new, type_scope: TypeScope.new, parent: nil)
    super
  end

  def define_var(name, node)
    with(value_scope: value_scope.define_var(name, node))
  end

  def define_fn(name, node)
    with(value_scope: value_scope.define_fn(name, node))
  end

  def define_type(name, type)
    with(type_scope: type_scope.define_type(name, type))
  end

  def resolve_var(name)
    value_scope.resolve_var(name)
  end

  def resolve_fn(name)
    value_scope.resolve_fn(name)
  end

  def resolve_type(name)
    type_scope.resolve_type(name)
  end

  def annotate_var(name, type)
    with(value_scope: value_scope.annotate_var(name, type))
  end

  def annotate_fn(name, type)
    with(value_scope: value_scope.annotate_fn(name, type))
  end
end

TypeScope = Data.define(:types) do
  def initialize(types: { 'Int' => Type.int, 'Bool' => Type.bool, 'String' => Type.string })
    super
  end

  def define_type(name, type)
    with(types: types.merge(name => type))
  end

  def resolve_type(name)
    types[name]
  end
end

ValueScope = Data.define(:vars, :functions) do
  def initialize(vars: {}, functions: {})
    super
  end

  def define_var(name, node)
    with(vars: vars.merge(name => node))
  end

  def define_fn(name, fn)
    with(functions: functions.merge(name => fn))
  end

  def annotate_var(name, type)
    define_var(name, resolve_var(name).annotate(type))
  end

  def annotate_fn(name, type)
    define_fn(name, resolve_fn(name).annotate(type))
  end

  def resolve_var(name)
    vars[name]
  end

  def resolve_fn(name)
    functions[name]
  end
end

UnboundVar = Data.define(:name, :range)
TypedVar = Data.define(:name, :type, :range)
UnboundFunction = Data.define(:name, :arity, :range)

TypedFunction = Data.define(:name, :type, :range) do
  def arity
    type.parameters.size
  end
end

RecordType = Data.define(:name, :fields)
TypedRecordType = Data.define(:name, :type, :range)
