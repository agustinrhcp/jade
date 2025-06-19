Context = Data.define(:value_scope, :type_scope, :parent, :substitution) do
  def initialize(
    value_scope:
    ValueScope.new,
    type_scope:
    TypeScope.new,
    substitution: {},
    parent: nil
  )
    super
  end

  VarEntry = Data.define(:name, :type)
  FunctionEntry = Data.define(:name, :parameters, :return_type, :type)

  def define_var(name)
    with(value_scope: value_scope.define_var(name, VarEntry.new(name, nil)))
  end

  def define_fn(name, parameters)
    with(
      value_scope: value_scope.define_fn(
        name, FunctionEntry.new(name, parameters, nil, nil),
      )
    )
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
    value_scope.resolve_var(name)
      .with(type:)
      .then { value_scope.define_var(name, it) }
      .then { with(value_scope: it) }
  end

  def annotate_fn(name, type)
    value_scope.resolve_fn(name)
      .with(type:)
      .then { value_scope.define_fn(name, it) }
      .then { with(value_scope: it) }
  end

def extend_substitution(name, type)
    with(substitution: substitution.merge(name => type))
  end

  def resolve_substitution(name)
    substitution[name]
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
