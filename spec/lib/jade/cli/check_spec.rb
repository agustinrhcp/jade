require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade/cli/check'

module Jade
  describe CLI::Check do
    let(:root) { Dir.mktmpdir('jade-check-spec') }
    let(:project) { Project.find(root) }

    before do
      FileUtils.mkdir_p(File.join(root, 'lib'))
      File.write(File.join(root, 'jade.json'), JSON.generate(source_roots: ['lib']))
    end

    after { FileUtils.rm_rf(root) }

    def write(name, source)
      File.write(File.join(root, 'lib', "#{name}.jd"), source)
    end

    def messages(*files)
      CLI::Check
        .diagnose(project, files)
        .map(&:message)
    end

    let(:good) do
      <<~JADE
        module Good exposing (shout)

        def shout(m: Maybe(String)) -> String
          m |> Maybe.with_default("nothing")
        end
      JADE
    end

    let(:invented) do
      <<~JADE
        module Bad exposing (total)

        def total(xs: List(Int)) -> Int
          xs |> List.fold_left(0, (a, b) -> { a + b })
        end
      JADE
    end

    it 'is quiet when everything checks' do
      write('good', good)

      expect(messages).to be_empty
    end

    it 'catches a stdlib function that does not exist' do
      write('bad', invented)

      expect(messages).to include(/List\.fold_left/)
    end

    it 'checks every source when given no files' do
      write('good', good)
      write('bad', invented)

      expect(messages).to include(/List\.fold_left/)
    end

    it 'checks only what it is given' do
      write('good', good)
      write('bad', invented)

      expect(messages('lib/good.jd')).to be_empty
    end

    it 'takes a path relative to the source root as well as the project root' do
      write('bad', invented)

      expect(messages('bad.jd')).to eql messages('lib/bad.jd')
    end

    it 'refuses a path that is not there rather than checking nothing' do
      expect { messages('nope.jd') }.to raise_error(/no such file/)
    end

    # Both entries reach Bad, and each load reports its diagnostics.
    it 'reports a shared broken module once' do
      write('bad', invented)
      write('uses_bad', <<~JADE)
        module UsesBad exposing (go)

        import Bad


        def go -> Int
          Bad.total([1, 2])
        end
      JADE

      expect(messages.grep(/List\.fold_left/)).to have(1).item
    end
  end
end
