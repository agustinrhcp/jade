require 'fileutils'

require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'
require 'jade/registry'
require 'jade/frontend'
require 'jade/codegen'
require 'jade/module_loader/cache'
require 'jade/module_loader/dependency_resolver'
require 'jade/module_loader/dependency_graph'
require 'jade/module_loader/normalize'
require 'jade/module_loader/topological_sort'
require 'jade/diagnostics'
require 'jade/diagnostics/renderer'

require 'jade/stdlib'

module Jade
  module ModuleLoader
    extend self

    def load(source_root, path, cache_dir: nil, tolerant: false, overlays: {})
      Source.load(source_root, path, overlays:)
        .then { load_(it, new_registry(source_root, overlays:), entry: true) }
        .then { Stdlib.apply(it) }
        .then { compile(it, cache_dir:, tolerant:) }
    end

    def load_import(module_name, registry)
      return registry if registry.get(module_name)&.ast

      Source
        .load_from_module_name(registry.source_root, module_name, overlays: registry.overlays)
        .then { load_(it, registry) }
    end

    def emit(registry, path: '.jade/build')
      registry
        .modules
        .each_value
        .reject { Stdlib.is_intrinsic?(it) }
        .each { write_entry(it, path) }

      registry
    end

    private

    def compile(registry, cache_dir: nil, tolerant: false)
      registry
        .modules_in_topo_order
        .reject { Stdlib.is_stdlib?(it) }
        .reduce([registry, {}]) do |(acc, digests), entry|
          compiled, digest = compile_with_cache(entry, acc, digests, cache_dir, tolerant)

          [acc.update_module(compiled), digests.merge(entry.name => digest)]
        end
        .first
    end

    def compile_with_cache(entry, registry, digests, cache_dir, tolerant)
      return [compile_one(entry, registry, tolerant:), nil] unless cache_dir

      key = direct_deps(entry.name, registry)
        .filter_map { |dep| digests[dep]&.then { [dep, it] } }
        .then { Cache.compute_key(entry, it) }

      Cache.read(cache_dir, entry.name, key) ||
        compile_and_write(entry, registry, cache_dir, key, tolerant)
    end

    def compile_and_write(entry, registry, cache_dir, key, tolerant)
      compile_one(entry, registry, tolerant:)
        .then { [it, it.interface_digest] }
        .tap { |(compiled, digest)| Cache.write(cache_dir, entry.name, compiled, key, digest) }
    end

    def write_entry(entry, path)
      full = File.join(path, entry.path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, entry.generated)
    end

    def compile_one(entry, registry, tolerant: false)
      Frontend
        .run_entry(entry, registry)
        .map { Codegen.generate_entry(it, registry.update_module(it)) }
        .on_err do |errors|
          diagnostics = errors.reduce(Diagnostics::List.empty) { |list, err| list.add(err.to_diagnostic(registry)) }

          if tolerant
            Ok[entry.with(diagnostics:)]
          else
            $stderr.puts Diagnostics::Renderer.new.render_all(diagnostics)
            raise CompilationError, diagnostics.items.map(&:message).join(", ")
          end
        end => Ok(compiled)

      compiled
    end

    def direct_deps(module_name, registry)
      registry.dependency_graph.nodes[module_name] || []
    end

    def load_(source, registry, entry: false)
      Lexer.tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .on_err do |err|
          Diagnostics::List
            .empty
            .add(err.to_diagnostic(source: source))
            .then { $stderr.puts Diagnostics::Renderer.new.render_all(it) }

          raise CompilationError, err.message
        end => Ok([raw_ast, comments])

      Frontend::CommentAttacher
        .attach(raw_ast, comments, source)
        .then { Registry.entry(source.to_module_name).with(ast: it, source:, entry:) }
        .then { registry.add_module(it) }
    end

    def new_registry(source_root, overlays: {})
      Registry
        .new
        .with(source_root:, overlays:)
        .then { Stdlib.load(it) }
    end
  end
end
