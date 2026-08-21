require 'spec_helper'

require 'jade'

module Jade
  describe Extensions do
    after { described_class.reset! }

    let(:deriver) do
      Module.new do
        def self.supports?(interface) = interface == 'Fake.Thing'
        def self.derive(*) = nil
      end
    end

    let(:check) do
      Module.new do
        def self.check(ctx) = ctx.name == 'Fake.go' ? [ctx.node] : []
      end
    end

    it 'takes a deriver from an allowed gem' do
      described_class.register_deriver('jade-sql', deriver)

      expect(Frontend::TypeChecking::Constraints::Deriving.derivable?('Fake.Thing'))
        .to be true
    end

    it 'refuses one from a gem that is not allowed' do
      expect { described_class.register_deriver('some-gem', deriver) }
        .to raise_error(described_class::NotAllowed, /some-gem may not extend/)
    end

    it 'leaves the built-in derivers alone' do
      expect(Frontend::TypeChecking::Constraints::Deriving.derivable?('Basics.Eq'))
        .to be true
    end

    it 'runs a registered check for every call' do
      described_class.register_check('jade-sql', :call, check)

      expect(described_class.check_call('Fake.go', [], :the_node, nil, nil, nil)).to eql [:the_node]
      expect(described_class.check_call('Other.go', [], :the_node, nil, nil, nil)).to eql []
    end

    it 'hands the check the call node, not only its types' do
      described_class.register_check('jade-sql', :call, check)

      expect(described_class.check_call('Fake.go', [], :the_node, nil, nil, nil)).to eql [:the_node]
    end

    it 'refuses a phase it does not have' do
      expect { described_class.register_check('jade-sql', :after_everything, check) }
        .to raise_error(described_class::UnknownPhase, /no such check phase/)
    end

    it 'says nothing when the callee cannot be named' do
      described_class.register_check('jade-sql', :call, check)

      expect(described_class.check_call(nil, [], :the_node, nil, nil, nil)).to eql []
    end

    it 'costs nothing when no check is registered' do
      expect(described_class.check_call('Fake.go', [], :the_node, nil, nil, nil)).to eql []
    end

    it 'registers a deriver once, however many times it is asked' do
      2.times { described_class.register_deriver('jade-sql', deriver) }

      expect(described_class.derivers.length).to eql 1
    end
  end
end
