require 'jade/parsing'

require 'jade/symbol'
require 'jade/registry'
require 'jade/type'
require 'jade/frontend'
require 'jade/lexer'
require 'jade/ast'
require 'jade/codegen'
require 'jade/compiler'
require 'jade/interop'
require 'jade/stdlib'

module Jade
  extend self

  def setup(&block)
    @compiler = Compiler.new(&block)
  end

  def require(path)
    @compiler ||= Compiler.new
    @compiler.require(path)
  end
end
