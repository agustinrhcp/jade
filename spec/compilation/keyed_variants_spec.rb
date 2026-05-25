require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Keyed variants' do
    include_context 'with test compiler'

    describe 'construction with kwargs' do
      let(:source) do
        <<~JADE
          module M exposing (make)

          type Stuff
            = V1(Int)
            | V2(paid_amount: Int, tax_amount: Int, issued_amount: Int)


          def make -> Stuff
            V2(paid_amount: 100, tax_amount: 20, issued_amount: 80)
        JADE
      end

      it 'builds a variant carrying the keyed fields directly' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        result = M::Internal.make
        expect(result).to be_a(M::V2).and have_attributes(
          paid_amount: 100,
          tax_amount: 20,
          issued_amount: 80,
        )
      end
    end

    describe 'pattern destructure binding' do
      let(:source) do
        <<~JADE
          module M exposing (total)

          type Stuff
            = V1(Int)
            | V2(paid_amount: Int, tax_amount: Int)


          def total(s: Stuff) -> Int
            case s
            of V1(n) -> n
            of V2(r) -> r.paid_amount + r.tax_amount
        JADE
      end

      it 'binds the variant instance and supports field access' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v1 = M::V1[7]
        v2 = M::V2[100, 20]

        expect(M::Internal.total(v1)).to eql 7
        expect(M::Internal.total(v2)).to eql 120
      end
    end

    describe 'pattern destructure by field' do
      let(:source) do
        <<~JADE
          module M exposing (paid)

          type Stuff = V(paid_amount: Int, tax_amount: Int)


          def paid(s: Stuff) -> Int
            case s
            of V({ paid_amount: pa, tax_amount: _ }) -> pa
        JADE
      end

      it 'destructures fields by name' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v = M::V[100, 20]
        expect(M::Internal.paid(v)).to eql 100
      end
    end

    describe 'update inside case' do
      let(:source) do
        <<~JADE
          module M exposing (bump_paid)

          type Stuff = V(paid_amount: Int, tax_amount: Int)


          def bump_paid(s: Stuff) -> Stuff
            case s
            of V(r) -> V({ r | paid_amount: r.paid_amount + 1 })
        JADE
      end

      it 'updates a payload field via record update' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v = M::V[100, 20]
        bumped = M::Internal.bump_paid(v)
        expect(bumped).to be_a(M::V).and have_attributes(paid_amount: 101, tax_amount: 20)
      end
    end

    describe 'single-field keyed variant' do
      let(:source) do
        <<~JADE
          module M exposing (get_id, make_credit)

          type Source
            = CreditSource(credit_id: Int)
            | ReceiptSource(receipt_id: Int)


          def make_credit(id: Int) -> Source
            CreditSource(credit_id: id)


          def get_id(s: Source) -> Int
            case s
            of CreditSource(c) -> c.credit_id
            of ReceiptSource(c) -> c.receipt_id
        JADE
      end

      before { test_compiler.require('m', source) }

      it 'constructs and pattern-matches without an inner record wrapper' do
        v = M::Internal.make_credit(42)
        expect(v).to be_a(M::CreditSource).and have_attributes(credit_id: 42)
        expect(M::Internal.get_id(v)).to eql 42
      end

      it 'accepts direct positional Ruby construction' do
        v = M::CreditSource[7]
        expect(M::Internal.get_id(v)).to eql 7
      end

      it 'accepts kwarg Ruby construction' do
        v = M::ReceiptSource[receipt_id: 9]
        expect(M::Internal.get_id(v)).to eql 9
      end
    end

    describe 'variant equality' do
      let(:source) do
        <<~JADE
          module M exposing (make)

          type Stuff = V(paid_amount: Int, tax_amount: Int)


          def make(p: Int, t: Int) -> Stuff
            V(paid_amount: p, tax_amount: t)
        JADE
      end

      it 'compares structurally across separate constructions' do
        test_compiler.require('m', source)

        a = M::Internal.make(100, 20)
        b = M::Internal.make(100, 20)
        c = M::Internal.make(100, 30)

        expect(a).to eq b
        expect(a).not_to eq c
      end
    end

    describe 'type errors' do
      context 'when a kwarg field is missing' do
        let(:source) do
          <<~JADE
            module M exposing (make)

            type Stuff = V(paid_amount: Int, tax_amount: Int)


            def make -> Stuff
              V(paid_amount: 100)
          JADE
        end

        it 'fails with a type mismatch on the record argument' do
          expect { test_compiler.require('m', source) }
            .to raise_error(CompilationError, /tax_amount/)
        end
      end

      context 'when a kwarg field has the wrong type' do
        let(:source) do
          <<~JADE
            module M exposing (make)

            type Stuff = V(paid_amount: Int, tax_amount: Int)


            def make -> Stuff
              V(paid_amount: "oops", tax_amount: 20)
          JADE
        end

        it 'fails with a type mismatch' do
          expect { test_compiler.require('m', source) }
            .to raise_error(CompilationError, /String|Int/)
        end
      end
    end
  end
end
