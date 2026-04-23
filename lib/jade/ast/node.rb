module Jade
  module AST
    module Node
      @@_next_id = 0

      def self.next_id
        @@_next_id += 1
      end
    end
  end
end
