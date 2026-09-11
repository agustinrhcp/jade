require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'a string literal' do
    it 'spans its quotes' do
      source = Source.new(uri: 'x', text: 'x = "ab"')

      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:, parser: Parsing.program_body) }
        .then { |result| result => Ok([body, _]); body.expressions.first.expression.range }
        .then { expect(source.text.byteslice(it.begin, it.size)).to eq '"ab"' }
    end

    it 'is underlined whole in a diagnostic' do
      source = <<~JADE
        module Lit exposing (one)

        def one -> Int
          xs = [1, "ab"]
          1
        end
      JADE

      rendered =
        begin
          ModuleLoader.load(Dir.tmpdir, 'lit.jd', overlays: { 'lit.jd' => source })
        rescue CompilationError => e
          Diagnostics::Renderer.new(colors: false).render_all(e.diagnostics)
        end

      source_line = rendered.lines.find { it.include?('xs = [1, "ab"]') }
      underline = rendered.lines.find { it.include?('^') }

      expect(underline.index('^')).to eq source_line.index('"')
      expect(underline.count('^')).to eq 4
    end
  end
end
