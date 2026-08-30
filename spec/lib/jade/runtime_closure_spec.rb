require 'spec_helper'

require 'rbconfig'

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
      root = File.expand_path('../../../lib', __dir__)

      run([RbConfig.ruby, '-I', root, '-e', "#{script}; puts $LOADED_FEATURES"])
        .lines(chomp: true)
        .select { |f| f.start_with?("#{root}/") }
        .map { |f| f.delete_prefix("#{root}/") }
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

    # Pending until 075. `boot!` requires the stdlib DSL, whose types are
    # strings that `Symbol.parse` has to read, so booting the intrinsics
    # pulls in the parser and the AST. It does not even get that far from a
    # bare runtime: loading those files without the compiler already
    # present raises. Delete the `pending` when it stops.
    it 'boots the intrinsics without the compiler' do
      pending 'ticket 075: the intrinsics are declared in the compiler'

      expect(loaded_under_lib("require 'jade/runtime'; Jade::Runtime.boot!").grep(COMPILER))
        .to be_empty
    end
  end
end
