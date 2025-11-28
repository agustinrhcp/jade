require 'jade/symbol'
require 'jade/registry'
require 'jade/type'
require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'
require 'jade/codegen'
require 'jade/build'

module Jade
  extend self

  def require(path)
    Jade::Build.build(path)
  end
end
