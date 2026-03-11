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

          context "with a constraint" do
            it "applies the substitution to the constraint type" do
              a = Type.var(1, "a")

              constraint = Type.eq(a)

              subs = Substitution.new.bind(a.id, Type.int)

              expect(subs.apply(constraint))
                .to eq(Type.eq(Type.int))
            end
          end

          it "fully resolves chained substitutions" do
            a = Type.var(1, "a")
            b = Type.var(2, "b")

            subs =
              Substitution
                .new
                .bind(a.id, b)
                .bind(b.id, Type.int)

            expect(subs.apply(a)).to eq(Type.int)
          end

          context "when constraints reference substituted vars" do
            it "updates the constraint type" do
              a = Type.var(1, "a")

              constraints = [Type.eq(a)]

              subs = Substitution.new.bind(a.id, Type.int)

              result = constraints.map { subs.apply(_1) }

              expect(result).to eq([Type.eq(Type.int)])
            end

            it "applies substitution inside nested types in constraints" do
              a = Type.var(1, "a")

              maybe_a = Type.maybe(a)
              constraint = Type.eq(maybe_a)

              subs = Substitution.new.bind(a.id, Type.int)

              result = subs.apply(constraint)

              expect(result).to eq(Type.eq(Type.maybe(Type.int)))
            end
          end
        end
      end
    end
  end
end
