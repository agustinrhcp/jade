require 'fileutils'

require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'
require 'jade/registry'
require 'jade/frontend'
require 'jade/codegen'
require 'jade/module_loader/dependency_resolver'
require 'jade/module_loader/dependency_graph'
require 'jade/module_loader/topological_sort'
require 'jade/diagnostics'
require 'jade/diagnostics/renderer'

require 'jade/stdlib'

module Jade
  module ModuleLoader
    extend self

    def load(source_root, path)
      Source.load(source_root, path)
        .then { load_(it, new_registry(source_root), entry: true) }
        .then { Stdlib.apply(it) }
        .then { compile(it) }
    end

    def load_import(module_name, registry)
      already_loaded = registry.get(module_name)
      return registry if already_loaded&.ast

      Source
        .load_from_module_name(registry.source_root, module_name)
        .then { load_(it, registry) }
    end

    def emit(registry, path: '.jade/build')
      registry.modules.each do |(_, entry)|
        next if Stdlib.is_intrinsic?(entry)

        full_path = File.join(path, entry.path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, entry.generated)
      end

      registry
    end

    private

    def compile(registry)
      registry
        .modules_in_topo_order
        .reject { Stdlib.is_stdlib?(it) }
        .reduce(registry) do |acc, entry|
          Frontend
            .run_entry(entry, acc)
            .map { Codegen.generate_entry(it, acc.update_module(it)) }
            .map { acc.update_module(it) }
            .on_err do
              it
                .reduce(Diagnostics::List.empty) { _1.add(_2.to_diagnostic(acc)) }
                .then do |diagnostics|
                  $stderr.puts Diagnostics::Renderer.new.render_all(diagnostics)
                  raise CompilationError, diagnostics.items.map(&:message).join(", ")
                end
            end => Ok(new)

          new
        end
    end

    def load_(source, registry, entry: false)
      Lexer.tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .on_err do |err|
          Diagnostics::List
            .empty
            .error(err.message, source:, span: err.span, label: err.label)
            .then { err.notes.reduce(it) { |d, ann| d.public_send(ann.kind, ann.message) } }
            .then { $stderr.puts Diagnostics::Renderer.new.render_all(it) }

          raise CompilationError, err.message
        end => Ok([ast, comments])

      ast = Frontend::CommentAttacher.attach(ast, comments, source)

      Registry
        .entry(source.to_module_name)
        .with(ast:)
        .with(source:)
        .with(entry:)
        .then do |entry|
          registry.add_module(entry)
        end
    end

    def new_registry(source_root)
      Registry
        .new
        .with(source_root:)
        .then { Stdlib.load(it) }
    end
  end
end
