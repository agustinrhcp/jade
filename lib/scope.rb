Scope = Data.define(:vars) do
  def initialize(vars: {})
    super
  end

  def define(var)
    with(vars: vars.merge(var.name.to_sym => var))
  end

  def resolve(name)
    vars[name.to_sym]
  end
end

UntypedVar = Data.define(:name, :range)
TypedVar = Data.define(:name, :type, :range)

