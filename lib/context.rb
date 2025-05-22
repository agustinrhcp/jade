Context = Data.define(:bindings) do
  def initialize(**bindings)
    super(bindings:)
  end

  def add(name, type)
    with(bindings: self.binding.merge(name => type))
  end

  def merge(context)
    context => { bindings: other_context_bindings }
    with(bindings: self.bindings.merge(other_context_bindings))
  end

  def get(name)
    bindings[name]
  end
end
