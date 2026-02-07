RSpec::Matchers.define :be_a_type_application_symbol do
  chain :named do |name|
    @name = name
  end

  chain :in_module do |module_name|
    @module_name = module_name
  end

  match do |actual|
    actual.is_a?(Jade::Symbol::TypeApplication) &&
      actual.constructor.is_a?(Jade::Symbol::TypeRef) &&
      (!defined?(@name) || actual.constructor.name == @name) &&
      (!defined?(@module_name) || actual.constructor.module_name == @module_name)
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be a type symbol" +
      (defined?(@module_name) ? " in module #{@module_name}" : "") +
      (defined?(@name) ? " named #{@name}" : "")
  end
end

RSpec::Matchers.define :be_an_int_symbol do
  match do |actual|
    be_a_type_application_symbol
      .named("Int")
      .in_module("Basics")
      .matches?(actual)
  end
end

RSpec::Matchers.define :be_string_symbol do
  match do |actual|
    be_a_type_application_symbol
      .named("String")
      .in_module("String")
      .matches?(actual)
  end
end

RSpec::Matchers.define :be_float_symbol do
  match do |actual|
    be_a_type_application_symbol
      .named("Float")
      .in_module("Basics")
      .matches?(actual)
  end
end

RSpec::Matchers.define :be_bool_symbol do
  match do |actual|
    be_a_type_application_symbol
      .named("Bool")
      .in_module("Basics")
      .matches?(actual)
  end
end
