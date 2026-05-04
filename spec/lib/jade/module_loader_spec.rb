require 'spec_helper'

require 'jade/module_loader'

module Jade
  describe ModuleLoader do
    subject { ModuleLoader.load('.', 'test/path.jd') }

    let(:source_code) do
      <<~JADE
        import Test.Pepe
      JADE
    end

    let(:pepe_source_code) do
      <<~JADE
        type Pepe = Lala | Coco
      JADE
    end

    before { allow(File).to receive(:read).with('./test/path.jd') { source_code } }
    before { allow(File).to receive(:read).with('./test/pepe.jd') { pepe_source_code } }

    it { is_expected.to be_a Registry }
    its(:dependency_graph) { is_expected.to_not be_empty }

    describe 'the dependency graph' do
      subject { super().dependency_graph }

      its(:size) { is_expected.to eql 7 }

      its(:nodes) { is_expected.to include('Test.Path' => ['Test.Pepe']) }
    end

    describe 'its modules in topo order' do
      subject { super().modules_in_topo_order.map(&:name) }

      it { is_expected.to eql %w[Maybe Result Decode.Params Calendar Clock Test.Pepe Test.Path] }
    end

    describe 'its modules' do
      subject { super().get('Test.Path') }

      its(:ast) { is_expected.to_not be_nil }
      its(:generated) { is_expected.to eql "$LOAD_PATH.unshift(File.expand_path(\"lib\")); require_relative 'test/pepe.rb'" }
    end

    describe '.emit' do
      subject { super().then { ModuleLoader.emit(it) } }

      it 'writes ruby files' do
        expect(FileUtils).to receive(:mkdir_p).exactly(7).times
        expect(File).to receive(:write).with('.jade/build/maybe.rb', anything)
        expect(File).to receive(:write).with('.jade/build/result.rb', anything)
        expect(File).to receive(:write).with('.jade/build/decode/params.rb', anything)
        expect(File).to receive(:write).with('.jade/build/calendar.rb', anything)
        expect(File).to receive(:write).with('.jade/build/clock.rb', anything)
        expect(File).to receive(:write).with('.jade/build/test/path.rb', anything)
        expect(File).to receive(:write).with('.jade/build/test/pepe.rb', anything)

        subject
      end
    end
  end
end
