require 'spec_helper'

require 'tmpdir'
require 'rbconfig'
require 'fileutils'

require 'jade/cli/eject'

module Jade
  module CLI
    describe Eject do
      around do |example|
        Dir.mktmpdir('jade-eject') do |root|
          @root = root
          FileUtils.mkdir_p(File.join(root, 'lib'))
          File.write(File.join(root, 'jade.json'), '{ "source_roots": ["lib"] }')
          File.write(File.join(root, 'lib', 'greeter.jd'), <<~JADE)
            module Greeter exposing (greet)

            def greet(name: String) -> String
              "hello " ++ name
            end
          JADE
          File.write(File.join(root, 'lib', 'counter.jd'), <<~JADE)
            module Counter exposing (total)

            def total -> Int
              List.sum([1, 2, 3])
            end
          JADE

          Dir.chdir(root) { example.run }
        end
      end

      def eject!
        expect { Eject.run([]) }.to output(/Ejected to/).to_stdout
      end

      def ejected(script)
        IO
          .popen([RbConfig.ruby, '-e', script], chdir: File.join(@root, 'ejected'), err: [:child, :out], &:read)
          .tap { fail it unless $?.success? }
      end

      it 'runs without the gem' do
        eject!

        expect(ejected('require_relative "greeter"; print Greeter.greet("world")'))
          .to eq 'hello world'
      end

      it 'carries the intrinsics the code calls' do
        eject!

        expect(ejected('require_relative "counter"; print Counter.total')).to eq '6'
      end

      it 'leaves no require that would look for the gem' do
        eject!

        expect(ejected_files.select { File.read(it).match?(/require ['"]jade/) }).to be_empty
      end

      it 'takes every module, not only the ones something imports' do
        eject!

        expect(ejected_files.map { File.basename(it) }).to include('greeter.rb', 'counter.rb')
      end

      def ejected_files
        Dir.glob(File.join(@root, 'ejected', '**', '*.rb'))
      end
    end
  end
end
