require 'spec_helper'

require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/codegen'

module Jade
  describe Codegen do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:generation) do
      Lexer
        .tokenize(source)
        .then { Parser.parse(it) }
        .and_then  { Frontend.run(it) }
        .map  { Codegen.generate(*it) }
    end

    context 'an int literal' do
      let(:text) do
        <<~JADE
          42
        JADE
      end

      subject { generation => Ok(code); code }

      it { is_expected.to eql "42" }
    end

    context 'a string literal' do
      let(:text) do
        <<~JADE
          "Pepe"
        JADE
      end

      subject { generation => Ok(code); code }

      it { is_expected.to eql '"Pepe"' }
    end

    context 'a boolean literal' do
      let(:text) do
        <<~JADE
          True
        JADE
      end

      subject { generation => Ok(code); code }

      it { is_expected.to eql "true" }
    end
  end
end
