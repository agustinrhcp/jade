require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # What a Ruby caller sees when a value does not cross. They may not know
  # Jade, so the message has to name the call, the argument and the type.
  describe 'a rejected value' do
    include_context 'with test compiler'

    before do
      test_compiler.require(<<~JADE.strip)
        module Shop exposing (Item(..), price, total)

        struct Item = {
          sku: String,
          cents: Int
        }


        def price(item: Item) -> Int
          item.cents
        end


        def total(items: List(Item)) -> Int
          List.sum(List.map(items, price))
        end
      JADE
    end

    def message
      yield
      raise 'expected a rejection'
    rescue Interop::Error => e
      e.message
    end

    it 'names the call and the argument' do
      expect(message { Shop.price('nope') })
        .to eq 'Shop.price(item): expected Item, got String ("nope")'
    end

    it 'says nil rather than null' do
      expect(message { Shop.price(nil) }).to eq 'Shop.price(item): expected Item, got nil'
    end

    it 'reports a field that did not decode' do
      expect(message { Shop.price('sku' => 'a', 'cents' => 'lots') })
        .to eq 'Shop.price(item): expected Int, got String ("lots")'
    end

    it 'names the argument a list came in as' do
      expect(message { Shop.total([{ 'sku' => 'a', 'cents' => 1 }, 'nope']) })
        .to eq 'Shop.total(items): expected Item, got String ("nope")'
    end

    it 'keeps the symbol-keys message, which already says what to do' do
      expect(message { Shop.price(sku: 'a', cents: 1) })
        .to include 'expects a Hash with string keys', 'try "sku" rather than :sku'
    end
  end
end
