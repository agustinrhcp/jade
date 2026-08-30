require 'spec_helper'
require 'tmpdir'

require 'jade'

module Jade
  # Generated Ruby calls the runtime by name. A build left by another
  # version can call a helper this one no longer has, and no source
  # changed, so mtimes cannot see it.
  describe Compiler do
    subject(:compiler) do
      described_class.new do |c|
        c.project_root = root
        c.source_root = File.join(root, 'src')
      end
    end

    let(:root) { Dir.mktmpdir('jade-build') }
    let(:build) { File.join(root, '.jade/build') }

    before do
      FileUtils.mkdir_p(File.join(root, 'src'))
      File.write(
        File.join(root, 'src/stale_check.jd'),
        "module StaleCheck exposing (yes)\n\ndef yes() -> Bool\n  True\nend\n",
      )
    end

    it 'drops a build stamped by another compiler' do
      compiler.require('stale_check')
      File.write(File.join(build, 'stale_check.rb'), '# left by an older compiler')
      File.write(File.join(build, '.fingerprint'), 'not this one')

      Compiler
        .new do |c|
          c.project_root = root
          c.source_root = File.join(root, 'src')
        end
        .require('stale_check')

      expect(File.read(File.join(build, 'stale_check.rb'))).to include 'module StaleCheck'
    end

    it 'keeps a build its own compiler wrote' do
      compiler.require('stale_check')
      File.write(File.join(build, 'stale_check.rb'), '# hand edited')

      compiler.require('stale_check')

      expect(File.read(File.join(build, 'stale_check.rb'))).to eq '# hand edited'
    end
  end

  describe Compiler::Config do
    subject(:config) { described_class.new }

    describe '#source_root=' do
      it 'takes a root' do
        config.source_root = 'lib'

        expect(config.source_root).to eql 'lib'
      end

      it 'unwraps a one-element list, which is what setup blocks pass' do
        config.source_root = ['lib']

        expect(config.source_root).to eql 'lib'
      end

      it 'refuses more than one rather than dropping the rest' do
        expect { config.source_root = ['lib', 'app'] }
          .to raise_error(ArgumentError, /takes one root, got 2/)
      end
    end
  end
end
