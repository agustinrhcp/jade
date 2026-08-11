require 'spec_helper'

require 'jade'

module Jade
  describe ModuleLoader::ModuleName do
    def check(uri, text)
      source = Source.new(uri:, text:)

      Lexer.tokenize(source)
        .then { Parsing.parse(it, source:) } => Ok([ast, _comments])

      described_class.check(ast, source)
    end

    context 'the name agrees with the file' do
      it 'passes the ast through' do
        result = check('cart.jd', "module Cart exposing (n)\n\ndef n() -> Int\n  1\nend\n")

        expect(result).to be_a(Ok)
      end
    end

    context 'the name disagrees' do
      it 'returns the diagnostics rather than raising' do
        check('orders.jd', "module Cart exposing (n)\n\ndef n() -> Int\n  1\nend\n") => Err(diagnostics)

        expect(diagnostics.items.first.message)
          .to match(/declared as `Cart` but `orders.jd` defines `Orders`/)
      end
    end
  end

  describe ModuleLoader do
    let(:root) { Dir.mktmpdir('jade-module-name') }

    after { FileUtils.rm_rf(root) }

    def load(uri, source)
      ModuleLoader.load(root, uri, overlays: { uri => source }, tolerant: true)
    end

    context 'the declared name matches the file' do
      it 'compiles' do
        registry = load('cart.jd', "module Cart exposing (n)\n\ndef n() -> Int\n  1\nend\n")

        expect(registry.get('Cart')).not_to be_nil
      end
    end

    context 'nested in a directory' do
      it 'compiles' do
        source = "module Shop.Cart exposing (n)\n\ndef n() -> Int\n  1\nend\n"
        registry = load('shop/cart.jd', source)

        expect(registry.get('Shop.Cart')).not_to be_nil
      end
    end

    context 'the declared name disagrees with the file' do
      let(:source) { "module Cart exposing (n)\n\ndef n() -> Int\n  1\nend\n" }

      it 'names both sides' do
        expect { load('orders.jd', source) }
          .to raise_error(CompilationError, /declared as `Cart` but `orders.jd` defines `Orders`/)
      end

      it 'points at the declared name' do
        load('orders.jd', source)
      rescue CompilationError => e
        span = e.diagnostics.items.first.primary.span

        expect(source[span]).to eq('Cart')
      end

      it 'offers the file to move it to' do
        load('orders.jd', source)
      rescue CompilationError => e
        expect(e.diagnostics.items.first.annotations.map(&:message))
          .to include(a_string_matching(/move the file to `cart.jd`/))
      end
    end

    context 'a file with no module declaration' do
      it 'is left alone' do
        expect { load('bare.jd', "def n() -> Int\n  1\nend\n") }.not_to raise_error
      end
    end
  end
end
