require 'spec_helper'
require 'open3'
require 'tmpdir'

module Jade
  describe 'jade repl' do
    let(:dir) { Dir.mktmpdir('jade-repl-cli') }
    let(:lib) { File.expand_path('../../../../lib', __dir__) }
    let(:exe) { File.expand_path('../../../../exe/jade', __dir__) }

    after { FileUtils.rm_rf(dir) }

    def repl(script)
      Open3.capture2e(RbConfig.ruby, '-I', lib, exe, 'repl', stdin_data: script, chdir: dir)
    end

    it 'reads piped inputs to the end, one result each' do
      out, status = repl(<<~JADE)
        limit = 3

        def twice(n: Int) -> Int
          n * 2
        end

        twice(limit)
      JADE

      expect(out).to eq "limit = 3 : Int\ntwice : Int -> Int\n6 : Int\n"
      expect(status).to be_success
    end

    it 'exits 1 when an input fails' do
      _, status = repl("1 + \"a\"\n")

      expect(status.exitstatus).to eq 1
    end
  end
end
