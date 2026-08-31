require 'spec_helper'
require 'tmpdir'

require 'jade'
require 'jade/module_loader'

module Jade
  # The page claims things about the compiler. Compile every claim, so a
  # change that makes one false fails here rather than in front of whoever
  # was told to read the page.
  describe 'docs/guarantees.md' do
    Fence = Data.define(:lang, :tag, :body) do
      def module_name
        body[/module (\S+)/, 1]
      end
    end

    FENCES = File
      .read('docs/guarantees.md')
      .scan(/^```(\w+)(?: (\w+))?\n(.*?)^```$/m)
      .map { |lang, tag, body| Fence[lang, tag, body] }

    # A `raises` block runs against the last module shown compiling above
    # it, which is how someone reading the page would run it.
    def self.preceding_module(fence)
      FENCES.take_while { it != fence }.reverse.find { it.tag == 'compiles' }
    end

    def self.followed_by_expectation
      FENCES.each_cons(2).select { |_, second| second.tag == 'expected' }
    end

    # The file has to be named after the module it declares, so every
    # example on the page gets its own name and its own file.
    def path_for(source)
      "#{source[/module (\S+)/, 1].gsub(/(.)([A-Z])/, '\1_\2').downcase}.jd"
    end

    def compile(source)
      Dir.mktmpdir do |root|
        Dir.mkdir(File.join(root, 'src'))
        File.write(File.join(root, 'src', path_for(source)), source)
        ModuleLoader
          .load(File.join(root, 'src'), path_for(source), tolerant: true)
          .modules
          .each_value
          .reject { Stdlib.is_stdlib?(it) }
          .flat_map { it.diagnostics.items }
      end
    end

    it 'tags every fence, so none goes unchecked' do
      expect(FENCES.map(&:tag).uniq)
        .to contain_exactly('compiles', 'fails', 'raises', 'expected')
    end

    FENCES.select { it.tag == 'compiles' }.each do |fence|
      it "compiles #{fence.module_name}" do
        expect(compile(fence.body)).to be_empty
      end
    end

    followed_by_expectation.select { |first, _| first.tag == 'fails' }.each do |fence, expected|
      it "rejects #{fence.module_name}" do
        expect(compile(fence.body).map(&:message).join("\n"))
          .to include(expected.body.strip.delete_prefix('error: '))
      end
    end

    describe 'the calls Ruby is shown making' do
      around { |example| Dir.mktmpdir { |dir| @root = dir; example.run } }

      def load_module(source)
        FileUtils.mkdir_p(File.join(@root, 'src'))
        File.write(File.join(@root, 'src', path_for(source)), source)
        Compiler
          .new { |c| c.project_root = @root; c.source_root = File.join(@root, 'src') }
          .require(path_for(source).delete_suffix('.jd'))
      end

      followed_by_expectation.select { |first, _| first.tag == 'raises' }.each do |call, expected|
        source = preceding_module(call).body

        it "raises for #{call.body.strip}" do
          load_module(source)

          expect { eval(call.body) } # rubocop:disable Security/Eval
            .to raise_error(Interop::Error, expected.body.strip)
        end
      end
    end
  end
end
