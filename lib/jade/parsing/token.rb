require 'jade/parsing/combinators'

module Jade
  module Parsing
    module Token
      extend Combinators::Dsl

      parser(:identifier) { type(:identifier) }
      parser(:constant)   { type(:constant) }
    end
  end
end
