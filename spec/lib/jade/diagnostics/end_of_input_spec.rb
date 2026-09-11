require 'spec_helper'

require 'jade'

module Jade
  describe 'a parse error that runs out of input' do
    let(:source) do
      Source.new(uri: 'half.jd', text: "module Half exposing (f)\n\ndef f(n: Int) -> Int\n")
    end

    let(:diagnostic) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:) }
        .then { |result| result => Err(error); error.to_diagnostic(source:) }
    end

    let(:rendered) { Diagnostics::Renderer.new(colors: false).render(diagnostic) }

    it 'points at the last character written' do
      expect(rendered)
        .to include('--> half.jd:3:20')
        .and include('3 | def f(n: Int) -> Int')
    end

    it 'renders a label that has nowhere to point as the message alone' do
      Diagnostics::Diagnostic
        .error('Unexpected end of input', primary: Diagnostics::Label[source, nil, nil])
        .then { Diagnostics::Renderer.new(colors: false).render(it) }
        .then { expect(it).to eq 'error: Unexpected end of input' }
    end
  end
end
