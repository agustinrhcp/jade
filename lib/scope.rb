Scope = Data.define(:vars, :functions) do
  def initialize(vars: {}, functions: {})
    super
  end

  def define_unbound_var(name, range)
    write_var(UnboundVar.new(name, range))
  end

  def define_typed_var(name, type, range)
    write_var(TypedVar.new(name, type, range))
  end

  def define_unbound_function(name, range)
    write_fn(UnboundFunction.new(name, range))
  end

  def define_typed_function(name, type, range)
    write_fn(TypedFunction.new(name, type, range))
  end

  def resolve(name)
    vars[name.to_sym] || functions[name.to_sym]
  end

  private

  def write_var(var)
    with(vars: vars.merge(var.name.to_sym => var))
  end

  def write_fn(fn)
    with(functions: functions.merge(fn.name.to_sym => fn))
  end
end

UnboundVar = Data.define(:name, :range)
TypedVar = Data.define(:name, :type, :range)
UnboundFunction = Data.define(:name, :range)
TypedFunction = Data.define(:name, :type, :range)

