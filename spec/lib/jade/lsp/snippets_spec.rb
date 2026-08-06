require 'spec_helper'

require 'jade/lsp/snippets'

module Jade
  module LSP
    describe Snippets do
      describe '.catalog' do
        it 'covers the forms a signature can never teach' do
          expect(Snippets.catalog.map { it[:form] })
            .to include('lambda', 'case', 'interface', 'implements', 'uses')
        end

        it 'strips the LSP tab stops, keeping the hint they carried' do
          expect(Snippets.find('lambda')[:source]).to eql '(args) -> { body }'
        end

        # The template is what gets copied, so it teaches a branch per
        # variant. `else` is for matching literals, where exhaustiveness
        # isn't available — not the default shape of a `case`.
        it 'offers a branch per variant rather than an else fallback' do
          expect(Snippets.find('case')[:source]).not_to include('else')
        end

        it 'leaves nothing for an editor to place a cursor on' do
          expect(Snippets.catalog.map { it[:source] }.join).not_to include('${')
        end
      end

      describe '.find' do
        it 'is nil for a form the language does not have' do
          expect(Snippets.find('macro')).to be_nil
        end
      end

      # Templates, not programs — `def name(params) -> Type` has a parameter
      # with no annotation and doesn't parse. What has to hold is that every
      # form carries something to read.
      describe 'every snippet' do
        it 'has a source and a description' do
          Snippets.catalog.each do |snippet|
            expect(snippet[:source]).not_to be_empty
            expect(snippet[:detail]).not_to be_empty
          end
        end
      end
    end
  end
end
