require 'jade/ast/node'

module Jade
  module AST
    module Nodes
      def define(name, *fields)
        const_set(name, Data.define(*fields, :range, :symbol) {
          include Node

          define_method(:initialize) do |**kwargs|
            kwargs[:symbol] ||= nil
            super(**kwargs)
          end
        })
      end
    end
  end
end
