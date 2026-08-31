module Jade
  module Testing
    # `Broken` never reached a test, so it carries a module name where the
    # others carry a path.
    Passed = Data.define(:path)
    Failed = Data.define(:path, :reasons)
    Crashed = Data.define(:path, :error)
    Broken = Data.define(:module_name, :error)

    Timing = Data.define(:compile, :run)
  end
end
