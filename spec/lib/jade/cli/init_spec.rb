require 'spec_helper'
require 'tmpdir'

require 'jade/cli/init'

module Jade
  module CLI
    # Every tool that runs outside the app reads jade.json, so a project
    # without one is invisible to the CLI and the language server. This is
    # the two seconds that stops being a problem.
    describe Init do
      around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

      def init(*argv)
        described_class.run(argv)
      end

      it 'writes a manifest naming the source root' do
        expect { init }.to output(/Wrote jade.json/).to_stdout

        expect(JSON.parse(File.read('jade.json'))).to eq(
          'source_roots' => ['lib'], 'extensions' => []
        )
      end

      it 'creates the source root' do
        expect { init }.to output.to_stdout.and change { Dir.exist?('lib') }.to(true)
      end

      it 'takes the source root from the flag' do
        expect { init('--source-root', 'app/jade') }.to output.to_stdout

        expect(Dir.exist?('app/jade')).to be true
      end

      # Overwriting it would discard a source root, extension list and
      # entry points nobody can recover from the directory.
      it 'refuses to overwrite one that exists' do
        File.write('jade.json', '{ "source_roots": ["src"] }')

        expect { init }
          .to raise_error(SystemExit)
          .and output(/jade.json already exists/).to_stderr

        expect(File.read('jade.json')).to eq '{ "source_roots": ["src"] }'
      end

      context 'with a .gitignore' do
        it 'adds the build directory to it' do
          File.write('.gitignore', "tmp/\n")

          expect { init }.to output(%r{Added \.jade/}).to_stdout

          expect(File.read('.gitignore')).to eq "tmp/\n.jade/\n"
        end

        it 'leaves one that already ignores it alone' do
          File.write('.gitignore', ".jade\n")

          expect { init }.to output(/already ignored/).to_stdout

          expect(File.read('.gitignore')).to eq ".jade\n"
        end
      end

      it 'says what to add when there is no .gitignore' do
        expect { init }.to output(%r{Add \.jade/ to \.gitignore}).to_stdout

        expect(File.exist?('.gitignore')).to be false
      end
    end
  end
end
