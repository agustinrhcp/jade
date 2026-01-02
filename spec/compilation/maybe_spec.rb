require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Compiling a jd file' do
    subject { ModuleLoader.load('spec/compilation', 'maybe.jd') }

    it { is_expected.to be_a Registry }

    it 'does not throw errors' do
      expect { subject }.to_not raise_error
    end

    context 'emiting' do
      subject { super().then { ModuleLoader.emit(it) } }

      before do
        File.delete(".jade/build/maybe.rb") if File.exist?(".jade/build/maybe.rb")
      end

      it 'writes a file for the compiled module' do
        expect { subject }
          .to change { File.exist?(".jade/build/maybe.rb") }
          .from(false).to(true)
      end
    end

    describe 'requiring the generated file' do
      compiler = Jade::Compiler.new do |c|
        c.source_root = 'spec/compilation'
        c.project_root = File.expand_path("../..", __dir__)
      end

      compiler.require('maybe')

      it 'works' do
        expect(Maybe.with_default.call(Maybe::Just[2], 0)).to be 2
        expect(Maybe.with_default.call(Maybe::Nothing[], 0)).to be 0
      end
    end
  end
end
