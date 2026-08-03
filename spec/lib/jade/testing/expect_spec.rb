require 'spec_helper'

require 'jade'

module Jade
  describe 'Expect' do
    let(:compiler) { TestCompiler.new }

    def outcome(body, decls: '')
      name = "ExpectProbe#{@seq = (@seq || 0) + 1}"

      compiler.require(<<~JADE)
        module #{name} exposing (probe)

        import Expect exposing (Expectation)


        def probe -> Expectation
          #{body.strip.gsub("\n", "\n  ")}
        end#{decls.empty? ? '' : "\n\n\n#{decls.strip}"}
      JADE

      case Object.const_get(name)::Internal.probe
      in ::Expect::Pass then :pass
      in ::Expect::Fail(reasons)
        reasons.map { [it.description, it.actual, it.expected] }
      end
    end

    it 'passes an equality that holds' do
      expect(outcome('Expect.equal(1, 1)')).to eql :pass
    end

    it 'renders both sides of a failed equality as Jade source' do
      expect(outcome('Expect.equal([1, 2], [1, 3])'))
        .to eql [['values to be equal', '[1, 2]', '[1, 3]']]

      expect(outcome('Expect.equal("a", "b")'))
        .to eql [['values to be equal', '"a"', '"b"']]
    end

    it 'passes an inequality that holds' do
      expect(outcome('Expect.not_equal(1, 2)')).to eql :pass
    end

    it 'says what a failed inequality wanted instead of repeating the value' do
      expect(outcome('Expect.not_equal(1, 1)'))
        .to eql [['values to differ', '1', 'not 1']]
    end

    it 'names the field it was given' do
      expect(outcome('Expect.field("age", 3, 3)')).to eql :pass
      expect(outcome('Expect.field("name", "Agustin Cornu", "Agustin")'))
        .to eql [['field `name` to be equal', '"Agustin Cornu"', '"Agustin"']]
    end

    let(:results) do
      <<~JADE
        def good -> Result(Int, String)
          Ok(1)
        end


        def bad -> Result(Int, String)
          Err("boom")
        end
      JADE
    end

    let(:maybes) do
      <<~JADE
        def some -> Maybe(Int)
          Just(1)
        end


        def none -> Maybe(Int)
          Nothing
        end
      JADE
    end

    it 'reports the payload of the wrong Result arm' do
      expect(outcome('Expect.ok(good)', decls: results)).to eql :pass
      expect(outcome('Expect.ok(bad)', decls: results))
        .to eql [['an Ok', 'Err("boom")', 'Ok(_)']]

      expect(outcome('Expect.err(bad)', decls: results)).to eql :pass
      expect(outcome('Expect.err(good)', decls: results))
        .to eql [['an Err', 'Ok(1)', 'Err(_)']]
    end

    it 'reports the payload of the wrong Maybe arm' do
      expect(outcome('Expect.just(some)', decls: maybes)).to eql :pass
      expect(outcome('Expect.just(none)', decls: maybes))
        .to eql [['a Just', 'Nothing', 'Just(_)']]

      expect(outcome('Expect.nothing(none)', decls: maybes)).to eql :pass
      expect(outcome('Expect.nothing(some)', decls: maybes))
        .to eql [['Nothing', 'Just(1)', 'Nothing']]
    end

    it 'checks booleans' do
      expect(outcome('Expect.true(True)')).to eql :pass
      expect(outcome('Expect.false(False)')).to eql :pass
      expect(outcome('Expect.true(False)')).to eql [['value to be True', 'False', 'True']]
    end

    it 'keeps every failure in a combined expectation, not just the first' do
      expect(outcome(<<~JADE.strip))
        Expect.all(
          [
            Expect.equal(1, 2),
            Expect.equal(3, 3),
            Expect.true(False),
          ],
        )
      JADE
        .to eql [
          ['values to be equal', '1', '2'],
          ['value to be True', 'False', 'True'],
        ]
    end

    it 'passes a combined expectation whose parts all pass' do
      expect(outcome('Expect.all([Expect.equal(1, 1), Expect.true(True)])')).to eql :pass
    end

    it 'lets a module build its own matcher out of `failure`' do
      matcher = <<~JADE
        def be_even(n: Int) -> Expectation
          if Basics.mod(n, 2) == 0 then
            Expect.Pass
          else
            Expect.failure("an even number", String.from_int(n), "even")
          end
        end
      JADE

      expect(outcome('be_even(4)', decls: matcher)).to eql :pass
      expect(outcome('Expect.all([be_even(4), be_even(3)])', decls: matcher))
        .to eql [['an even number', '3', 'even']]
    end

    it 'combines a pair through `and`' do
      expect(outcome('Expect.equal(1, 1) |> Expect.and(Expect.true(False))'))
        .to eql [['value to be True', 'False', 'True']]
    end
  end
end
