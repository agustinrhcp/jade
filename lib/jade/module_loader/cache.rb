require 'digest'
require 'fileutils'

module Jade
  module ModuleLoader
    module Cache
      extend self

      MAGIC = 'jade-cache-v2'

      def read(cache_dir, module_name, key)
        path = path_for(cache_dir, module_name)
        return nil unless File.exist?(path)

        Marshal.load(File.binread(path)) => [MAGIC, ^key, interface_digest, entry]
        [entry, interface_digest]
      rescue StandardError, NoMatchingPatternError
        nil
      end

      def write(cache_dir, module_name, entry, key, interface_digest)
        path = path_for(cache_dir, module_name)
        FileUtils.mkdir_p(File.dirname(path))

        tmp = "#{path}.#{Process.pid}.tmp"
        File.binwrite(tmp, Marshal.dump([MAGIC, key, interface_digest, entry]))
        File.rename(tmp, path)
      end

      def clean(cache_dir)
        FileUtils.rm_rf(cache_dir)
      end

      def compute_key(entry, dep_digests)
        Digest::SHA256.hexdigest(
          [compiler_fingerprint, entry.source.text, dep_digests.sort.inspect]
            .join("\n")
        )
      end

      def compiler_fingerprint
        @compiler_fingerprint ||=
          Dir[File.expand_path('../**/*.rb', __dir__)]
            .sort
            .map { Digest::SHA256.file(it).hexdigest }
            .then { Digest::SHA256.hexdigest(it.join) }
      end

      private

      def path_for(cache_dir, module_name)
        File.join(cache_dir, "#{module_name.tr('.', '/')}.entry")
      end
    end
  end
end
