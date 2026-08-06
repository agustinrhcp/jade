require 'spec_helper'

require 'jade'
require 'jade/signature'

module Jade
  describe Signature do
    def var(id, name)
      Type.var(id, name)
    end

    describe '.render' do
      it 'keeps declared names when they are unambiguous' do
        Type
          .function([var('t1', 'a')], var('t2', 'b'))
          .then { expect(Signature.render('f', it, [])).to eql 'f : (a) -> b' }
      end

      it 'separates distinct variables that share a name' do
        Type
          .function([var('t1', 'a')], var('t2', 'a'))
          .then { expect(Signature.render('f', it, [])).to eql 'f : (a) -> b' }
      end

      it 'does not reuse a name already claimed further left' do
        Type
          .function([var('t1', 'b'), var('t2', 'x')], var('t3', 'b'))
          .then { expect(Signature.render('f', it, [])).to eql 'f : (b, x) -> a' }
      end

      it 'renames the same variable consistently everywhere it appears' do
        Type
          .function([var('t1', 'a'), var('t2', 'a')], var('t2', 'a'))
          .then { expect(Signature.render('f', it, [])).to eql 'f : (a, b) -> b' }
      end

      it 'carries constraints through the renaming' do
        Type::Constraint['Basics.Comparable', var('t2', 'a'), nil, 0]
          .then do |constraint|
            Type
              .function([var('t1', 'a')], var('t2', 'a'))
              .then { Signature.render('f', it, [constraint]) }
              .then { expect(it).to eql 'f : Comparable b => (a) -> b' }
          end
      end
    end
  end
end
