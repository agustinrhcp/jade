module Jade
  module Type
    module Base
      def to_s
        fail NotImplementedError
      end
    end

    module Displayable
      def display_as(name)
        with(display: name)
      end

      def to_s
        display || render
      end

      def annotated
        display ? "#{display} (= #{with(display: nil)})" : render
      end

      # `display` is deliberately out of `identity`: two spellings of one type
      # must still unify, hash alike and compare equal.
      def ==(other)
        other.is_a?(self.class) && identity == other.identity
      end

      alias eql? ==

      def hash
        [self.class, *identity].hash
      end
    end
  end
end
