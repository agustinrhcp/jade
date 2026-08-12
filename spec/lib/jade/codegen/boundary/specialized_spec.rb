require 'spec_helper'
require 'jade'
require 'jade/codegen/boundary'

module Jade
  describe Codegen::Boundary::Specialized do
    let(:registry) { Registry.new.with(source_root: []).then { Stdlib.load(it) } }

    let(:int_t) { Type.int }

    def list_t(inner)
      Type.constructor('List.List').apply([inner])
    end

    def maybe_t(inner)
      Type.constructor('Maybe.Maybe').apply([inner])
    end

    def fn_t(args, ret)
      Type.function(args, ret)
    end

    describe '.encode_expr' do
      subject { described_class.encode_expr(type, 'v', registry) }

      context 'a type whose encoder is identity' do
        let(:type) { int_t }

        it { is_expected.to eq(:identity) }
      end

      context 'a list of identity elements' do
        let(:type) { list_t(int_t) }

        it { is_expected.to eq(:identity) }
      end

      # A Just still has to be unwrapped, so the element being identity does
      # not make the Maybe one.
      context 'a Maybe of identity elements' do
        let(:type) { maybe_t(int_t) }

        it { is_expected.to be_a(String) }
        it { is_expected.to include('Jade::Maybe::Just') }
      end

      context 'a type with no specialized emission' do
        let(:type) { fn_t([int_t], int_t) }

        it { is_expected.to be_nil }
      end
    end
  end
end
