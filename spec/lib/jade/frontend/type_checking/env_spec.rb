require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Env do
        include SymbolFactory

        describe '.empty' do
          subject { described_class.empty(VarGen.new) }

          its(:bindings) { is_expected.to be_empty }
        end
      end
    end
  end
end
