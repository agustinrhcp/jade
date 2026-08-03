require 'spec_helper'

require 'jade'
require 'jade/frontend'

module Jade
  module Frontend
    module TypeChecking
      describe 'Call to Task coercion' do
        let(:env) { TypeChecking::Env.empty }

        def applied(constructor, args)
          Type.constructor(constructor).apply(args)
        end

        let(:int)    { Type.constructor('Basics.Int').apply([]) }
        let(:string) { Type.constructor('Basics.String').apply([]) }

        let(:call) { applied('Call.Call', [int, string]) }
        let(:task) { applied('Task.Task', [int, string]) }

        it 'accepts a Call where a Task is expected' do
          expect(Unification.unify(call, task, env)).to be_a(Jade::Ok)
        end

        it 'rejects a Task where a Call is expected' do
          expect(Unification.unify(task, call, env)).to be_a(Jade::Err)
        end

        it 'still unifies the ok and error arms' do
          mismatched = applied('Task.Task', [string, string])

          expect(Unification.unify(call, mismatched, env)).to be_a(Jade::Err)
        end

        it 'binds type variables through the coercion' do
          var = Type::Var.new(id: 1, name: nil)
          open_task = applied('Task.Task', [var, string])

          result = Unification.unify(call, open_task, env)

          expect(result).to be_a(Jade::Ok)
          result => Jade::Ok[substitution]
          expect(substitution.apply(var)).to eq(int)
        end

        it 'leaves unrelated constructors alone' do
          list_of_int = applied('List.List', [int])

          expect(Unification.unify(list_of_int, task, env)).to be_a(Jade::Err)
        end
      end
    end
  end
end
