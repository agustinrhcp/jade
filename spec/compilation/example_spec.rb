require 'spec_helper'

require 'jade/module_loader'

module Jade
  describe 'Compiling a jd file' do
    subject { ModuleLoader.load('spec/compilation', 'example.jd') }

    it { is_expected.to be_a Registry }

    it 'does not throw errors' do
      expect { subject }.to_not raise_error
    end

    context 'emiting' do
      subject { super().then { ModuleLoader.emit(it) } }

      before do
        File.delete(".jade/build/example.rb") if File.exist?(".jade/build/example.rb")
      end

      it 'writes a file for the compiled module' do
        expect { subject }
          .to change { File.exist?(".jade/build/example.rb") }
          .from(false).to(true)
      end
    end
  end
end
