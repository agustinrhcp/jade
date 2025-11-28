require 'spec_helper'

require 'jade/module_loader'

module Jade
  describe ModuleLoader do
    subject { ModuleLoader.load('.', 'test/path.jd') }

    let(:source_code) do
      <<~JADE
        import Test.Basics
        import Test.String
      JADE
    end

    let(:basics_source_code) do
      <<~JADE
        type Int = Int_
        type Float = Float_
      JADE
    end

    let(:string_source_code) do
      <<~JADE
        import Test.Basics

        type String = String_
      JADE
    end

    before { allow(File).to receive(:read).with('./test/path.jd') { source_code } }
    before { allow(File).to receive(:read).with('./test/basics.jd') { basics_source_code } }
    before { allow(File).to receive(:read).with('./test/string.jd') { string_source_code } }

    it { is_expected.to be_a Registry }
    its(:dependency_graph) { is_expected.to_not be_empty }

    describe 'the dependency graph' do
      subject { super().dependency_graph }

      its(:size) { is_expected.to eql 3 }

      its(:nodes) { is_expected.to include('Test.Path' => ['Test.Basics', 'Test.String']) }
      its(:nodes) { is_expected.to include('Test.String' => ['Test.Basics']) }
      its(:nodes) { is_expected.to include('Test.Basics' => []) }
    end

    describe 'its modules in topo order' do
      subject { super().modules_in_topo_order.map(&:name) }

      it { is_expected.to eql %w[Test.Basics Test.String Test.Path] }
    end

    describe 'its modules' do
      subject { super().get('Test.Path') }

      its(:ast) { is_expected.to_not be_nil }
      its(:generated) { is_expected.to eql "$LOAD_PATH.unshift(File.expand_path(\"lib\")); require 'test/basics.rb'; require 'test/string.rb'" }
    end

    describe '.emit' do
      subject { super().then { ModuleLoader.emit(it) } }

      it 'writes ruby files' do
        expect(FileUtils).to receive(:mkdir_p).exactly(3).times
        expect(File).to receive(:write).with('.jade/build/test/path.rb', anything)
        expect(File).to receive(:write).with('.jade/build/test/basics.rb', anything)
        expect(File).to receive(:write).with('.jade/build/test/string.rb', anything)

        subject
      end
    end
  end
end
