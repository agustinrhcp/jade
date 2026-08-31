module Jade
  module Codegen
    # Codegen runs on a program the frontend already proved well-typed, so
    # this is a bug in jade, not in the source. RuntimeError so the CLI
    # reports it as a message rather than a backtrace.
    MissingDictionary = Class.new(RuntimeError)
    UnrepresentableType = Class.new(RuntimeError)
  end
end
