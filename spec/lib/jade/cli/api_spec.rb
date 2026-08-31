require 'spec_helper'

require 'tmpdir'
require 'json'
require 'fileutils'

require 'jade/cli/api'

module Jade
  module CLI
    describe Api do
      around do |example|
        Dir.mktmpdir('jade-api') do |root|
          @root = root
          FileUtils.mkdir_p(File.join(root, 'lib'))
          File.write(File.join(root, 'jade.json'), '{ "source_roots": ["lib"] }')
          File.write(File.join(root, 'lib', 'shop.jd'), <<~JADE)
            module Shop exposing (Item(..), price)

            struct Item = { cents: Int }


            def price(item: Item) -> Int
              item.cents
            end
          JADE

          Dir.chdir(root) { example.run }
        end
      end

      def surface
        JSON.parse(capture { Api.run(['--origin', 'project']) })
      end

      def capture
        original = $stdout
        $stdout = StringIO.new
        yield
        $stdout.string
      ensure
        $stdout = original
      end

      it 'lists what a caller can depend on' do
        expect(surface.dig('Shop', 'symbols'))
          .to eq(
            'Shop.Item' => { 'constructor' => '(Int) -> Item', 'struct' => 'struct Item = { cents : Int }' },
            'Shop.price' => { 'function' => '(Item) -> Int' },
          )
      end

      it 'writes the file --check reads' do
        capture { Api.run(%w[--origin project --out jade-api.json]) }

        expect { Api.run(%w[--origin project --check jade-api.json]) }.not_to raise_error
      end

      it 'exits 1 when the surface moved' do
        capture { Api.run(%w[--origin project --out jade-api.json]) }
        File.write(File.join(@root, 'lib', 'shop.jd'), <<~JADE)
          module Shop exposing (Item(..), price)

          struct Item = { cents: Int }


          def price(item: Item, tax: Int) -> Int
            item.cents + tax
          end
        JADE

        expect { Api.run(%w[--origin project --check jade-api.json]) }
          .to raise_error(SystemExit)
          .and output(/is out of date/).to_stderr
      end
    end
  end
end
