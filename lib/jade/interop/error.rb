module Jade
  module Interop
    class Error < StandardError; end

    class PortNotRegistered < Error
      def initialize(module_name, function_name)
        super(
          "Port `#{function_name}` on `#{module_name}` is not a Jade port. " \
            "Add `extend Jade::Port` to `#{module_name}` and declare it with " \
            "`task :#{function_name} do |t, ...| ... end`."
        )
      end
    end
  end
end
