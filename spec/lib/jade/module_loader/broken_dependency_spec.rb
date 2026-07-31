require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'
require 'jade/module_loader'

module Jade
  describe ModuleLoader, 'a module whose dependency failed to compile' do
    let(:project) { Dir.mktmpdir('jade-cascade-spec') }

    after { FileUtils.rm_rf(project) }

    def write(name, body)
      File.write(File.join(project, "#{name}.jd"), body)
    end

    subject(:diagnostics) do
      ModuleLoader
        .load(project, 'user.jd', tolerant: true)
        .modules
        .values
        .reject { it.diagnostics.items.empty? }
        .to_h { [it.name, it.diagnostics.items.map(&:message).join(' ')] }
    end

    before do
      write('broken', <<~JADE)
        module Broken exposing (value)

        def value -> Int
          "not an int"
        end
      JADE

      write('user', <<~JADE)
        module User exposing (go)

        import Broken


        def go -> Int
          Broken.value + 1
        end
      JADE
    end

    it 'reports the error in the module that has it' do
      expect(diagnostics['Broken']).to include('should be Int')
    end

    it 'says why the dependent was not checked, rather than crashing' do
      expect(diagnostics['User']).to include('Not checked: Broken failed to compile')
    end

    it 'does not attribute the dependency error to the dependent' do
      expect(diagnostics['User']).to_not include('should be Int')
    end

    context 'two modules broken independently' do
      before do
        write('also_broken', <<~JADE)
          module AlsoBroken exposing (other)

          def other -> Int
            True
          end
        JADE

        write('user', <<~JADE)
          module User exposing (go)

          import AlsoBroken
          import Broken


          def go -> Int
            Broken.value + AlsoBroken.other
          end
        JADE
      end

      it 'reports both roots rather than stopping at the first' do
        expect(diagnostics.keys).to include('Broken', 'AlsoBroken')
      end
    end
  end
end
