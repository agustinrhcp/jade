require 'spec_helper'

require 'jade/source'
require 'jade/diagnostics'
require 'jade/diagnostics/renderer'

module Jade
  describe Diagnostics::Renderer do
    subject(:renderer) { described_class.new(colors: false) }

    # "total = price + "hello""
    #  t(0)o(1)t(2)a(3)l(4) (5)=(6) (7)p(8)r(9)i(10)c(11)e(12) (13)+(14) (15)"(16)
    let(:source) { Source.new(uri: 'user.jd', text: %(total = price + "hello"\n)) }
    let(:span)   { 16...23 }  # `"hello"` — col 17, length 7

    describe '#render' do
      let(:diagnostic) do
        Diagnostics::List.empty
          .error('type mismatch',
            source:,
            span:,
            label: 'expected Number, got String')
          .note('"+" is defined for Number + Number')
          .help('convert the value to a Number')
          .items.first
      end

      subject(:output) { renderer.render(diagnostic) }

      it 'renders the full diagnostic' do
        expect(output).to eq(<<~TEXT.chomp)
          error: type mismatch
            --> user.jd:1:17
            |
          1 | total = price + "hello"
            |                 ^^^^^^^ expected Number, got String
            |
            = note: "+" is defined for Number + Number
            = help: convert the value to a Number
        TEXT
      end

      it 'points to the right column' do
        lines = output.lines
        source_line = lines.find { _1.match?(/^\d+ \|/) }
        underline_line = lines.find { _1.include?("^") }

        source_col = source_line.index('"')
        underline_col = underline_line.index('^')

        expect(underline_col).to eq(source_col)
      end
    end

    describe '#render with a secondary label' do
      let(:def_span) { 0...5 }

      let(:diagnostic) do
        Diagnostics::Diagnostic.error(
          'undefined variable `price`',
          primary: Diagnostics::Label[source, span, 'not in scope'],
          secondary: [Diagnostics::Label[source, def_span, 'defined here']],
        )
      end

      subject(:output) { renderer.render(diagnostic) }

      it 'renders the primary label' do
        expect(output).to include('^^^^^^^ not in scope')
      end

      it 'renders the secondary label with dashes' do
        expect(output).to include('----- defined here')
      end
    end

    describe '#render_all' do
      let(:source2) { Source.new(uri: 'other.jd', text: "foo bar\n") }

      let(:diagnostics) do
        Diagnostics::List.empty
          .error('type mismatch', source:, span: (16...23), label: 'expected Number')
          .error('undefined variable', source: source2, span: (0...3), label: 'not found')
      end

      subject(:output) { renderer.render_all(diagnostics) }

      it 'renders all diagnostics' do
        expect(output).to include('error: type mismatch')
        expect(output).to include('error: undefined variable')
      end

      it 'separates them with a blank line' do
        expect(output.split("\n\n")).to have(2).items
      end

      it 'points to the correct files' do
        expect(output).to include('--> user.jd:1:17')
        expect(output).to include('--> other.jd:1:1')
      end
    end

    describe 'multi-line source — single-line span' do
      let(:source) do
        Source.new(uri: 'multi.jd', text: <<~JADE)
          def add(a: Int, b: Int) -> Int
            a + "hello"
        JADE
      end

      # `"hello"` is on line 2: `  a + "hello"`
      # line 1 ends with \n at index 30, so line 2 starts at 31
      # `  a + ` is 6 chars, so `"` is at index 31 + 6 = 37
      let(:span) { 37...44 }

      subject(:output) { renderer.render(Diagnostics::Diagnostic.error('type mismatch', primary: Diagnostics::Label[source, span, 'expected Int'])) }

      it 'shows the correct line number' do
        expect(output).to include('--> multi.jd:2:')
      end

      it 'shows the source line' do
        expect(output).to include('a + "hello"')
      end

      it 'underlines the right span' do
        expect(output).to include('^^^^^^^ expected Int')
      end
    end

    describe 'multi-line span' do
      let(:source) do
        Source.new(uri: 'block.jd', text: <<~JADE)
          def pauls_age -> Int
            42
        JADE
      end

      # Span covers the whole def block
      let(:span) { 0...source.text.length }

      subject(:output) { renderer.render(Diagnostics::Diagnostic.error('wrong return type', primary: Diagnostics::Label[source, span, 'declared here'])) }

      it 'renders all lines of the span' do
        expect(output).to eq(<<~TEXT.chomp)
          error: wrong return type
            --> block.jd:1:1
            |
          1 | def pauls_age -> Int
            | ^^^^^^^^^^^^^^^^^^^^
          2 |   42
            | ^^^^ declared here
            |
        TEXT
      end

      it 'shows the annotation under the last line' do
        expect(output).to include('^^^^ declared here')
      end

      it 'shows all subsequent lines as context' do
        expect(output).to include('  42')
      end
    end
  end
end
