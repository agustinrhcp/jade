module Jade
  module LSP
    State = Data.define(:source_root, :cache_dir, :buffers, :registry, :published) do
      def self.empty
        new(source_root: nil, cache_dir: nil, buffers: {}, registry: nil, published: [])
      end

      # No manifest means no cache directory to share with the CLI, and
      # every compile starts from nothing.
      def with_project(project, root)
        with(source_root: project&.source_root || root, cache_dir: project&.cache_path)
      end

      def put_buffer(uri, text)
        with(buffers: buffers.merge(uri => text))
      end

      def close(uri)
        with(buffers: buffers.except(uri))
      end

      def set_registry(reg)
        with(registry: reg)
      end

      # Cleared next round, whether or not the file is still open.
      def with_published(uris)
        with(published: uris)
      end
    end
  end
end
