require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Keyed variants' do
    include_context 'with test compiler'

    describe 'construction with kwargs' do
      let(:source) do
        <<~JADE
          module M exposing(make)

          type Stuff
            = V1(Int)
            | V2(paid_amount: Int, tax_amount: Int, issued_amount: Int)

          def make() -> Stuff
            V2(paid_amount: 100, tax_amount: 20, issued_amount: 80)
          end
        JADE
      end

      it 'builds a variant with a record payload' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        result = M.make.call
        result.deconstruct => [payload]
        expect(payload).to have_attributes(
          paid_amount: 100,
          tax_amount: 20,
          issued_amount: 80,
        )
      end
    end

    describe 'pattern destructure binding' do
      let(:source) do
        <<~JADE
          module M exposing(total)

          type Stuff
            = V1(Int)
            | V2(paid_amount: Int, tax_amount: Int)

          def total(s: Stuff) -> Int
            case s
            of V1(n) then n
            of V2(r) then r.paid_amount + r.tax_amount
            end
          end
        JADE
      end

      it 'binds the payload as a record and supports field access' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v1 = M::V1[7]
        v2 = M::V2[Data.define(:paid_amount, :tax_amount)[100, 20]]

        expect(M.total.call(v1)).to eql 7
        expect(M.total.call(v2)).to eql 120
      end
    end

    describe 'pattern destructure by field' do
      let(:source) do
        <<~JADE
          module M exposing(paid)

          type Stuff = V(paid_amount: Int, tax_amount: Int)

          def paid(s: Stuff) -> Int
            case s
            of V(paid_amount: pa, tax_amount: _) then pa
            end
          end
        JADE
      end

      it 'destructures inner record fields by name' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v = M::V[Data.define(:paid_amount, :tax_amount)[100, 20]]
        expect(M.paid.call(v)).to eql 100
      end
    end

    describe 'update inside case' do
      let(:source) do
        <<~JADE
          module M exposing(bump_paid)

          type Stuff = V(paid_amount: Int, tax_amount: Int)

          def bump_paid(s: Stuff) -> Stuff
            case s
            of V(r) then V({ r | paid_amount: r.paid_amount + 1 })
            end
          end
        JADE
      end

      it 'updates a single payload field via record update' do
        expect { test_compiler.require('m', source) }.to_not raise_error

        v = M::V[Data.define(:paid_amount, :tax_amount)[100, 20]]
        bumped = M.bump_paid.call(v)
        bumped.deconstruct => [payload]
        expect(payload).to have_attributes(paid_amount: 101, tax_amount: 20)
      end
    end

    describe 'type errors' do
      context 'when a kwarg field is missing' do
        let(:source) do
          <<~JADE
            module M exposing(make)

            type Stuff = V(paid_amount: Int, tax_amount: Int)

            def make() -> Stuff
              V(paid_amount: 100)
            end
          JADE
        end

        it 'fails with a type mismatch on the record argument' do
          expect { test_compiler.require('m', source) }
            .to raise_error(RuntimeError, /tax_amount/)
        end
      end

      context 'when a kwarg field has the wrong type' do
        let(:source) do
          <<~JADE
            module M exposing(make)

            type Stuff = V(paid_amount: Int, tax_amount: Int)

            def make() -> Stuff
              V(paid_amount: "oops", tax_amount: 20)
            end
          JADE
        end

        it 'fails with a type mismatch' do
          expect { test_compiler.require('m', source) }
            .to raise_error(RuntimeError, /String|Int/)
        end
      end
    end
  end
end
