require 'spec_helper'

require 'ast/pretty_printer'

module AST
  describe PrettyPrinter do
    subject { PrettyPrinter.print(node) }

    context 'a simple literal' do
      let(:node) { lit(2) }

      it { is_expected.to eql 'Literal(value: 2)' }
    end

    context 'a binary operation' do
      let(:node) { bin(lit(2), :+, lit(2)) }

      it do 
        is_expected.to eql(
          <<~PRETTY.chomp
            Binary(
              Literal(value: 2),
              operator: :+,
              Literal(value: 2)
            )
          PRETTY
        )
      end
    end

    context 'a grouping' do
      let(:node) { bin(grp(bin(lit(2), :+, lit(2))), :*, lit(4)) }

      it do 
        is_expected.to eql(
          <<~PRETTY.chomp
            Binary(
              Grouping(
                Binary(
                  Literal(value: 2),
                  operator: :+,
                  Literal(value: 2)
                )
              ),
              operator: :*,
              Literal(value: 4)
            )
          PRETTY
        )
      end
    end
  end
end
