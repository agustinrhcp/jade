require 'jade/version'
require 'jade/did_you_mean'
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

  def register_extension(root)
    extensions << root
  end

  # Convenience for extension gem entry files: registers `<entry>/<basename>`
  # by convention. Pass `__FILE__` from `lib/jade-foo.rb` to register
  # `lib/jade-foo/` as the search root.
  def extension(entry_file)
    register_extension(entry_file.delete_suffix('.rb'))
  end

  def extensions
    @extensions ||= []
  end

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
