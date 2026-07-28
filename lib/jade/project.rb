require 'json'
require 'pathname'

module Jade
  # A project's compiler settings, read from `jade.json` at its root.
  #
  # Without this, project config only exists as Ruby executed at app boot
  # (`Jade.setup`), so every tool that runs outside the app — the CLI, an
  # editor's LSP, a codegen task — is blind to it and has to guess the
  # source root and which extension gems to load.
  #
  # Subclassed rather than `Project = Data.define(...) do ... end` because
  # constants in that block land in `Jade`, not on the class — which would
  # put `Jade::DEFAULTS` in the gem's top namespace.
  class Project < Data.define(
    :root, :source_roots, :build_dir, :cache_dir, :extensions, :entries, :map
  )
    MANIFEST = 'jade.json'.freeze

    DEFAULTS = {
      source_roots: ['lib'],
      build_dir: '.jade/build',
      cache_dir: '.jade/cache',
      extensions: [],
      entries: [],
      map: {},
    }.freeze

    class NotFound < StandardError
      def initialize(from)
        super(<<~MSG)
          no #{MANIFEST} in #{from} or any parent directory

          Tools that run outside the app can't see a `Jade.setup` block, so
          they need the manifest to find your sources and load the gems
          that ship the modules you import. Write one at the project root:

            { "source_roots": ["lib"], "extensions": ["jade-sql"] }
        MSG
      end
    end

    # nil when there's no manifest — a project predating one is a legitimate
    # state, not a failure. Callers that need it say so with `find!`.
    def self.find(from = Dir.pwd)
      Pathname
        .new(from)
        .expand_path
        .ascend
        .find { (it + MANIFEST).file? }
        &.then { load(it) }
    end

    def self.find!(from = Dir.pwd)
      find(from) || fail(NotFound.new(from))
    end

    def self.load(root)
      (root + MANIFEST)
        .read
        .then { JSON.parse(it, symbolize_names: true) }
        .then { new(root: root.to_s, **DEFAULTS.merge(it)) }
        .tap { it.require_extensions }
    end

    def source_root
      File.expand_path(source_roots.first, root)
    end

    def build_path
      File.expand_path(build_dir, root)
    end

    def cache_path
      File.expand_path(cache_dir, root)
    end

    # Modules are addressed relative to the source root, but a path typed at
    # a shell or sent by an editor is relative to the project root. Accept
    # either, and say so when it's neither.
    def source_relative(path)
      [source_root, root]
        .map { File.expand_path(path, it) }
        .find { File.file?(it) }
        .then { it || fail("no such file: #{path}") }
        .then { Pathname.new(it).relative_path_from(source_root).to_s }
    end

    # Extensions register their search root when required, so this is what
    # lets a standalone tool resolve `Sql.Uuid` to the gem that ships it.
    #
    # Plain `require`, not `Kernel.require`: RubyGems overrides the private
    # instance method and leaves the module function alone, so
    # `Kernel.require` finds only what is already on the load path — never
    # an installed gem, which is the whole point here.
    def require_extensions
      extensions.each { require(it) }
    end
  end
end
