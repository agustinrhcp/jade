Scope = Data.define(:vars, :functions, :records) do
  def initialize(vars: {}, functions: {}, records: {})
    super
  end

  def define_unbound_var(name, range)
    write_var(UnboundVar.new(name, range))
  end

  def define_typed_var(name, type, range)
    write_var(TypedVar.new(name, type, range))
  end

  def define_unbound_function(name, arity, range)
    write_fn(UnboundFunction.new(name, arity, range))
  end

  def define_typed_function(name, type, range)
    write_fn(TypedFunction.new(name, type, range))
  end

  def resolve(name)
    vars[name.to_sym] || functions[name.to_sym]
  end

  def resolve_record(name)
    records[name.to_sym]
  end

  def define_record(name, fields)
    fields
      .map  { |f| RecordTypeField.new(f.name, f.type) }
      .then { |fs| RecordType.new(name, fs) }
      .then { |record| write_record(record) }
  end

  private

  def write_var(var)
    with(vars: vars.merge(var.name.to_sym => var))
  end

  def write_fn(fn)
    with(functions: functions.merge(fn.name.to_sym => fn))
  end

  def write_record(record)
    with(records: records.merge(record.name.to_sym => record))
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

RecordTypeField = Data.define(:name, :type)
RecordType = Data.define(:name, :fields)
