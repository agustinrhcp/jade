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
require 'jade/diagnostics'
require 'jade/diagnostics/renderer'

module Jade
  class CompilationError < StandardError
    attr_reader :diagnostics

    def initialize(diagnostics)
      @diagnostics = diagnostics
      super(diagnostics.items.map(&:message).join(", "))
    end
  end

  extend self

  def setup(&block)
    @compiler = Compiler.new(&block)
  end

  def require(path)
    @compiler ||= Compiler.new
    @compiler.require(path)
  rescue CompilationError => e
    $stderr.puts Diagnostics::Renderer.new.render_all(e.diagnostics)
    exit 1
  end
end
