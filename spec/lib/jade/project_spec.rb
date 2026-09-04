require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe Project do
    let(:root)   { Dir.mktmpdir('jade-project-spec') }
    let(:nested) { File.join(root, 'lib/api/handlers') }

    before { FileUtils.mkdir_p(nested) }
    after  { FileUtils.rm_rf(root) }

    def manifest(**keys)
      File.write(File.join(root, 'jade.json'), JSON.generate(keys))
    end

    describe '.find' do
      it 'ascends to the manifest' do
        manifest(source_roots: ['lib'])

        expect(Project.find(nested).root).to eql root
      end

      it 'is nil without one, since a project predating the manifest is fine' do
        expect(Project.find(nested)).to be_nil
      end

      it 'fills in what the manifest leaves out' do
        manifest(source_roots: ['lib'])

        expect(Project.find(root))
          .to have_attributes(build_dir: '.jade/build', cache_dir: '.jade/cache', extensions: [])
      end

      it 'refuses a key it does not know, so a typo is not silently ignored' do
        manifest(source_root: 'lib')

        expect { Project.find(root) }
          .to raise_error(Project::UnknownKey, /has no `source_root` setting/)
      end
    end

    describe '.find!' do
      it 'says how to write a manifest when there is none' do
        expect { Project.find!(nested) }
          .to raise_error(Project::NotFound, /source_roots/)
      end
    end

    describe '#source_relative' do
      before { manifest(source_roots: ['lib']) }

      subject(:project) { Project.find(root) }

      let(:file) { File.join(root, 'lib/api/handlers/envelopes.jd') }

      before { File.write(file, 'module Api.Handlers.Envelopes exposing ()') }

      it 'accepts a path relative to the source root' do
        expect(project.source_relative('api/handlers/envelopes.jd'))
          .to eql 'api/handlers/envelopes.jd'
      end

      it 'accepts one relative to the project root, which is what a shell gives' do
        expect(project.source_relative('lib/api/handlers/envelopes.jd'))
          .to eql 'api/handlers/envelopes.jd'
      end

      it 'accepts an absolute path' do
        expect(project.source_relative(file)).to eql 'api/handlers/envelopes.jd'
      end

      it 'names the file when it is neither' do
        expect { project.source_relative('lib/nope.jd') }
          .to raise_error(RuntimeError, /no such file: lib\/nope.jd/)
      end
    end

    # The failure this guards against — `Kernel.require` reaching only the
    # load path and never an installed gem — is invisible under `bundle
    # exec`, where every gem is already on it. Verified out of band with
    # `jade q` on a real project.
    describe 'extensions' do
      let(:gem_dir) { File.join(root, 'fake-gem') }

      before do
        FileUtils.mkdir_p(gem_dir)
        File.write(
          File.join(gem_dir, 'jade-fake.rb'),
          "Jade.register_extension('#{gem_dir}/jade-fake')",
        )
        $LOAD_PATH.unshift(gem_dir)
      end

      after do
        $LOAD_PATH.delete(gem_dir)
        Jade.extensions.delete("#{gem_dir}/jade-fake")
      end

      it 'requires them on load, so their search roots are registered' do
        manifest(source_roots: ['lib'], extensions: ['jade-fake'])

        expect { Project.find(root) }
          .to change { Jade.extensions.include?("#{gem_dir}/jade-fake") }
          .from(false).to(true)
      end

      it 'sets aside a key named after one of them, for that gem to read' do
        manifest(
          source_roots: ['lib'],
          extensions: ['jade-fake'],
          'jade-fake': { enums: { invoice_status: 'Invoice.Status' } },
        )

        expect(Project.find(root).extension_config)
          .to eql({ :'jade-fake' => { enums: { invoice_status: 'Invoice.Status' } } })
      end

      it 'leaves it empty when none of them claims anything' do
        manifest(source_roots: ['lib'], extensions: ['jade-fake'])

        expect(Project.find(root).extension_config).to eql({})
      end
    end

    describe 'seeding Compiler::Config' do
      it 'falls back to today defaults with no manifest' do
        expect(Compiler::Config.new(nil))
          .to have_attributes(source_root: nil, build_dir: '.jade/build', cache_dir: '.jade/cache')
      end

      it 'takes the source root from the manifest, absolute' do
        manifest(source_roots: ['lib'], build_dir: 'out')

        expect(Compiler::Config.new(Project.find(root)))
          .to have_attributes(source_root: File.join(root, 'lib'), build_dir: 'out')
      end

      it 'lets a setup block win, since it runs after' do
        manifest(source_roots: ['lib'])

        config = Compiler::Config.new(Project.find(root))
        config.source_root = 'elsewhere'

        expect(config.source_root).to eql 'elsewhere'
      end
    end
  end
end
