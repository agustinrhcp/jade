require 'spec_helper'

require 'rbconfig'
require 'tmpdir'

module Jade
  # Compiled code requires `jade/runtime` and nothing else, so whatever the
  # runtime drags in ships in every production image and has to be vendored
  # by an eject. The compiler is not part of that: the gem is a build tool.
  describe 'the runtime closure' do
    COMPILER = %r{lib/jade/(parsing|frontend|module_loader|formatter|lsp|cli|ast|symbol/parser)}

    ALLOWED_BEFORE_BOOT = %w[
      jade/debug.rb
      jade/decode.rb
      jade/interop/boundary.rb
      jade/interop/error.rb
      jade/interop/runtime.rb
      jade/result.rb
      jade/runtime.rb
    ].freeze

    # A fresh process: the suite has the whole compiler loaded, which is the
    # thing being measured.
    def loaded_under_lib(script)
      run([RbConfig.ruby, '-I', lib_root, '-e', "#{script}; puts $LOADED_FEATURES"])
        .lines(chomp: true)
        .select { |f| f.start_with?("#{lib_root}/") }
        .map { |f| f.delete_prefix("#{lib_root}/") }
    end

    def lib_root
      File.expand_path('../../../lib', __dir__)
    end

    def run(command)
      IO
        .popen(command, err: [:child, :out], &:read)
        .tap { fail "#{command.last}\n#{it}" unless $?.success? }
    end

    it 'is seven files before anything runs' do
      expect(loaded_under_lib("require 'jade/runtime'")).to match_array ALLOWED_BEFORE_BOOT
    end

    it 'loads no compiler before anything runs' do
      expect(loaded_under_lib("require 'jade/runtime'").grep(COMPILER)).to be_empty
    end

    it 'boots the intrinsics without the compiler' do
      expect(loaded_under_lib("require 'jade/runtime'; Jade::Runtime.boot!").grep(COMPILER))
        .to be_empty
    end

    # An app boots the runtime, then a rake task in the same process wants
    # the compiler.
    it 'still compiles when the compiler arrives after a runtime boot' do
      Dir.mktmpdir do |src|
        File.write(File.join(src, 'probe.jd'), <<~JADE)
          module Probe exposing (go)

          def go -> Int
            List.sum([1, 2, 3])
          end
        JADE

        expect(run([RbConfig.ruby, '-I', lib_root, '-e', <<~RUBY]))
          require 'jade/runtime'
          Jade::Runtime.boot!
          require 'jade'
          require 'jade/module_loader'
          print Jade::ModuleLoader.load(#{src.inspect}, 'probe.jd').get('Probe').generated.include?('def go')
        RUBY
          .to eq 'true'
      end
    end
  end
end
