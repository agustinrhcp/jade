require 'spec_helper'

require 'jade/module_loader'

module Jade
  module ModuleLoader
    describe TopologicalSort do
      let(:graph) do
        DependencyGraph.new
          .add('Basics', [])
          .add('String', ['Basics'])
          .add('Test', ['Basics', 'String'])
      end

      subject { described_class.sort(graph) }

      it { is_expected.to eql(['Basics', 'String', 'Test']) }

      context 'with cycles' do
        let(:graph) do
          DependencyGraph.new
            .add('Basics', [])
            .add('String', ['Basics'])
            .add('Test', ['Basics', 'String', 'OtherTest'])
            .add('OtherTest', ['Test'])
        end

        it 'raises an error' do
          expect { subject }.to raise_error(CycleDependencyError, /Test -> OtherTest -> Test/)
        end
      end
    end
  end
end
