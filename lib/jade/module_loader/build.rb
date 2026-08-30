require 'fileutils'

require 'jade/module_loader/cache'

module Jade
  module ModuleLoader
    # The emitted Ruby, as opposed to `Cache`, which holds compiled
    # modules. Generated code calls the runtime by name, so a build left
    # by another version of the compiler can call a helper this one no
    # longer has. Sources are untouched in that case, so mtimes say
    # nothing: keep the fingerprint next to the build and drop the build
    # when it does not match.
    module Build
      extend self

      FINGERPRINT = '.fingerprint'

      def discard_foreign(root)
        return unless File.exist?(root)
        return if fingerprint(root) == Cache.compiler_fingerprint

        FileUtils.rm_rf(root)
      end

      def stamp(root)
        File.write(File.join(root, FINGERPRINT), Cache.compiler_fingerprint)
      end

      private

      def fingerprint(root)
        File.join(root, FINGERPRINT).then { File.read(it) if File.exist?(it) }
      end
    end
  end
end
