require 'jade/symbol'
require 'jade/registry'
require 'jade/type'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'
require 'jade/codegen'
require 'jade/compiler'
require 'jade/interop'
require 'jade/stdlib'

module Jade
  class CompilationError < RuntimeError; end

  extend self

  def setup(&block)
    @compiler = Compiler.new(&block)
  end

  def require(path)
    @compiler ||= Compiler.new
    @compiler.require(path)
  rescue CompilationError
    exit 1
  end
end
