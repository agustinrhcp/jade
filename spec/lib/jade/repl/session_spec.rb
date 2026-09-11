require 'spec_helper'
require 'securerandom'

require 'jade/repl'

module Jade
  describe Repl::Session do
    let(:host) { Repl::Host.create(source_root: nil, space: "repl#{SecureRandom.hex(4)}") }
    let(:output) { Repl::Output[colors: false] }

    after { host.clean }

    def transcript(*inputs)
      inputs
        .reduce([Repl::Session.start(host), []]) do |(session, printed), input|
          session.submit(input).then do |outcome|
            [advance(session, outcome), printed + [output.render(outcome)]]
          end
        end
        .last
    end

    def advance(session, outcome)
      case outcome
      in Repl::Accepted(session: accepted) then accepted
      else session
      end
    end

    it 'shows a value with its type' do
      expect(transcript('1 + 2')).to eq ['3 : Int']
    end

    it 'binds a name for later inputs' do
      expect(transcript('limit = 3', 'limit * 2')).to eq ['limit = 3 : Int', '6 : Int']
    end

    it 'keeps the last value as `it`' do
      expect(transcript('20', 'it + 1')).to eq ['20 : Int', '21 : Int']
    end

    it 'declares a function' do
      function = <<~JADE
        def double(n: Int) -> Int
          n * 2
        end
      JADE

      expect(transcript(function, 'double(4)')).to eq ['double : Int -> Int', '8 : Int']
    end

    it 'shadows an earlier definition without touching what used it' do
      printed = transcript(
        "def rate -> Int\n  2\nend",
        'old = rate',
        "def rate -> Int\n  3\nend",
        '[old, rate]',
      )

      expect(printed.last).to eq '[2, 3] : List(Int)'
    end

    it 'shows a union and a struct the way they are written' do
      printed = transcript(
        'type Shape = Circle(Float) | Square(Float)',
        'struct Point = { x: Int, y: Int }',
        '[Circle(1.5)]',
        'Point(1, 2)',
      )

      expect(printed).to eq [
        'type Shape',
        'struct Point',
        '[Circle(1.5)] : List(Shape)',
        'Point(x: 1, y: 2) : Point',
      ]
    end

    describe 'a value of each kind' do
      {
        '"hi"' => '"hi" : String',
        "'c'" => "'c' : Char",
        '1.5 * 2.0' => '3.0 : Float',
        'True' => 'True : Bool',
        '[Just(1), Nothing]' => '[Just(1), Nothing] : List(Maybe(Int))',
        '(n) -> { n + 1 }' => '<function> : Int -> Int',
        '"a" ++ "b"' => '"ab" : String',
        '(1 + 2) * 3' => '9 : Int',
        "case 1\nin 1 then \"one\"\nelse \"other\"\nend" => '"one" : String',
      }.each do |input, shown|
        it "shows #{input}" do
          expect(transcript(input)).to eq [shown]
        end
      end
    end

    it 'shows a record with its fields' do
      expect(transcript('{ name: "Ann", age: 3 }').first).to start_with('{ age: 3, name: "Ann" } : ')
    end

    it 'shows a Dict as the call that builds it' do
      expect(transcript('import Dict', 'Dict.from_list([("a", 1)])').last)
        .to eq 'Dict.from_list([("a", 1)]) : Dict(String, Int)'
    end

    it 'implements an interface for a type from an earlier input' do
      printed = transcript(
        'struct Point = { x: Int, y: Int }',
        <<~JADE,
          import Show exposing (Show)


          implements Show(Point) with
            show: (p) -> { String.from_int(p.x) }
          end
        JADE
        'Show.show(Point(4, 0))',
      )

      expect(printed.drop(1)).to eq ['implements Show(Point)', '"4" : String']
    end

    it 'runs a task and shows its result' do
      expect(transcript('Task.succeed(1)').first).to start_with('Ok(1) : Result(Int, ')
    end

    it 'rejects an input that does not compile, pointing into it' do
      printed = transcript('1 + "a"', '1 + 1')

      expect(printed.first)
        .to include('error: Right side of (+) expects Int but found String')
        .and include('1 | 1 + "a"')
      expect(printed.last).to eq '2 : Int'
    end

    it 'rejects an input that raises and forgets it' do
      printed = transcript(<<~JADE, 'boom')
        def deep(n: Int) -> Int
          1 + deep(n)
        end

        boom = deep(1)
      JADE

      expect(printed.first).to start_with('error: stack level too deep')
      expect(printed.last).to include('Undefined variable boom')
    end

    it 'rejects an input that does not parse' do
      expect(transcript('def f(n: Int) -> Int').first)
        .to include('Unexpected end of input')
    end

    it 'says `<-` does not work yet' do
      expect(transcript('x <- Just(1)').first).to include('`<-` does not work at the prompt yet')
    end

    it 'gives a type without evaluating' do
      Repl::Session
        .start(host)
        .type_of('List.map([1], (n) -> { n * 2 })')
        .then { expect(output.render(it)).to eq 'List.map([1], (n) -> { n * 2 }) : List(Int)' }
    end
  end
end
