require 'spec_helper'

require 'jade/ast'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/frontend/comment_attacher'

module Jade
  describe AST::Node, '#doc' do
    let(:source) { Source.new(uri: 'test', text:) }

    let(:declarations) do
      Lexer.tokenize(source)
        .then { Parsing.parse(it, source:) }
        .map { |(ast, comments)| Frontend::CommentAttacher.attach(ast, comments, source) } => Ok(ast)

      ast.body.expressions.select { it.is_a?(AST::FunctionDeclaration) }
    end

    subject(:docs) { declarations.to_h { [it.name, it.doc(source)] } }

    context 'a comment directly above a declaration' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          # Inserts one row.
          def a -> Int
            1
          end
        JADE
      end

      it { is_expected.to eql('a' => '# Inserts one row.') }
    end

    context 'several comment lines with no gap' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          # Inserts one row.
          # Returns its id.
          def a -> Int
            1
          end
        JADE
      end

      it { is_expected.to eql('a' => "# Inserts one row.\n# Returns its id.") }
    end

    context 'a banner separated by a blank line' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          # RECORD -------

          def a -> Int
            1
          end
        JADE
      end

      it 'is not documentation' do
        expect(docs).to eql('a' => nil)
      end
    end

    context 'a banner followed by a doc comment' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          # RECORD -------

          # Inserts one row.
          def a -> Int
            1
          end
        JADE
      end

      it 'keeps only the block touching the declaration' do
        expect(docs).to eql('a' => '# Inserts one row.')
      end
    end

    context 'a section comment describing the functions that follow' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          # PG array predicates.
          # All bind the array as a single param.


          def a -> Int
            1
          end
        JADE
      end

      it 'is not attributed to the first function in the section' do
        expect(docs).to eql('a' => nil)
      end
    end

    context 'no comment at all' do
      let(:text) do
        <<~JADE
          module M exposing (a)

          def a -> Int
            1
          end
        JADE
      end

      it { is_expected.to eql('a' => nil) }
    end
  end
end
