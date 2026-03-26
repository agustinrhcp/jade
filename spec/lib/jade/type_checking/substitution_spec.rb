require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      describe Substitution do
        describe '#apply' do
          it "applies to vars" do
            a = Type.var(1, "a")
            subs = Substitution.new.bind(a.id, Type.int)
            expect(subs.apply(a)).to eql Type.int
          end

          it "does not apply to other vars" do
            b = Type.var(2, "b")
            subs = Substitution.new.bind(0, Type.int)
            expect(subs.apply(b)).to eql b
          end

          context 'with a function' do
            it "applies the substitution" do
              a = Type.var(1, "a")
              b = Type.var(2, "b")

              fn = Type.function([a], b)

              subs = Substitution.new.bind(a.id, Type.int)

              expect(subs.apply(fn))
                .to eq(Type.function([Type.int], b))
            end
          end

          describe 'applying substitution to open record' do
            let(:open_record) { Type.parse "{ a | id: Int }" }
            let(:substitution) { Substitution.new.bind('a', Type.parse('{ name: String, id: Int }')) }
  
            subject { substitution.apply(open_record) }
  
            it 'resolves to a closed record' do
              is_expected.to eq(Type.parse('{ name: String, id: Int }'))
            end
          end
        end
      end
    end
  end
end
