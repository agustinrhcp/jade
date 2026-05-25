module Jade
  module LSP
    State = Data.define(:source_root, :buffers, :registry) do
      def self.empty
        new(source_root: nil, buffers: {}, registry: nil)
      end

      def with_root(root)
        with(source_root: root)
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
    end
  end
end
