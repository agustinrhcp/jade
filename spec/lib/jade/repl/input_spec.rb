require 'spec_helper'

require 'jade/repl'

module Jade
  describe Repl::Input do
    describe '.complete?' do
      {
        'def double(n: Int) -> Int' => false,
        "def double(n: Int) -> Int\n  n * 2\nend" => true,
        "case 1\nin 1 then 2" => false,
        "[1,\n 2" => false,
        'xs |>' => false,
        '1 +' => false,
        '"unfinished' => false,
        '1 + 2' => true,
        'x = [1, 2]' => true,
      }.each do |text, complete|
        it "is #{complete} for #{text.inspect}" do
          expect(Repl::Input.complete?(text)).to be complete
        end
      end
    end

    describe '.parse' do
      def messages(text)
        Repl::Input.parse(text) => Err(diagnostics)
        diagnostics.items.map(&:message)
      end

      it 'takes declarations, bindings and a last expression' do
        expect(Repl::Input.parse("x = 1\n\nx + 1")).to be_a(Ok)
      end

      it 'refuses a bare expression before the last statement' do
        expect(messages("1\n2"))
          .to eq ['Only the last statement of an input can be a bare expression']
      end

      it 'refuses a pattern on the left of `=`' do
        expect(messages('(a, b) = (1, 2)'))
          .to eq ['Only a name can be bound at the prompt, not a pattern']
      end
    end
  end
end
