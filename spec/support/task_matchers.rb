RSpec::Matchers.define :be_task_ok do |expected|
  match do |actual|
    actual == ['ok', expected]
  end

  failure_message do |actual|
    %(expected task outcome ["ok", #{expected.inspect}], got #{actual.inspect})
  end
end

RSpec::Matchers.define :be_task_err do |expected|
  match do |actual|
    actual == ['err', expected]
  end

  failure_message do |actual|
    %(expected task outcome ["err", #{expected.inspect}], got #{actual.inspect})
  end
end
