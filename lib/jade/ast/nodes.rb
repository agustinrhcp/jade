require 'jade/ast/node'

module Jade
  module AST
    module Nodes
      def define(name, *fields)
        Data.define(
          *fields,
          :range,
          :symbol,
          :id,
          :leading_comments,
          :trailing_comments,
          :dangling_comments,
          :trailing_comma
        ) {
          include Node

          define_method(:initialize) do |**kwargs|
            kwargs[:symbol] ||= nil
            kwargs[:id]     ||= Node.next_id
            kwargs[:leading_comments]  ||= []
            kwargs[:trailing_comments] ||= []
            kwargs[:dangling_comments] ||= []
            kwargs[:trailing_comma]    ||= false
            super(**kwargs)
          end
        }
         .then { const_set(name, it) }
      end
    end
  end
end
