require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'dictionary passing — sibling same-iface markers on a single origin' do
    include_context 'with test compiler'

    it 'preserves slot order when a single call origin has two same-iface constraints' do
      test_compiler.require('repro_wipe', <<~JADE)
        module ReproWipe exposing (go)

        interface Show(a) with
          show : a -> String
        end


        implements Show(Int) with
          show: show_int
        end


        implements Show(String) with
          show: show_str
        end


        def show_int(n: Int) -> String
          "int"
        end


        def show_str(s: String) -> String
          "str"
        end


        def two_shows(x: a, y: b) -> String
          show(x) ++ "-" ++ show(y)
        end


        def wrap(x: a, y: b) -> String
          two_shows(x, y)
        end


        def go -> String
          wrap(42, "hi")
        end
      JADE

      expect(ReproWipe.go).to eql 'int-str'
    end
  end
end
