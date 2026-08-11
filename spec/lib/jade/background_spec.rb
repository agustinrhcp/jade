require 'spec_helper'

require 'jade'

module Jade
  describe Background do
    let(:task_def) { Jade::TaskDef.new('Mailer', 'send_welcome') }

    around do |example|
      previous = described_class.adapter
      example.run
      described_class.adapter = previous
    end

    describe 'the default inline adapter' do
      before { described_class.adapter = Background::Inline }

      it 'runs the port immediately' do
        ran = nil
        Jade::Tasks.register(task_def) { |_t, arg| ran = arg }

        described_class.enqueue(task_def, ['u-1'], {})

        expect(ran).to eq('u-1')
      end

      it 'returns an ok result carrying a job id' do
        Jade::Tasks.register(task_def) { |_t, _arg| nil }

        expect(described_class.enqueue(task_def, ['u-1'], {}))
          .to eq('inline:Mailer.send_welcome')
      end
    end

    describe 'a configured adapter' do
      let(:recorder) do
        Class.new do
          attr_reader :enqueued

          def initialize = @enqueued = []

          def enqueue(task_def, args, options)
            @enqueued << [task_def.to_s, args, options]
            'job-42'
          end
        end.new
      end

      before { described_class.adapter = recorder }

      it 'hands it the port name, the encoded args and the options' do
        described_class.enqueue(task_def, ['u-1'], { 'queue' => 'mailers' })

        expect(recorder.enqueued)
          .to eq([['Mailer.send_welcome', ['u-1'], { 'queue' => 'mailers' }]])
      end

      it 'returns the adapter job id' do
        expect(described_class.enqueue(task_def, ['u-1'], {}))
          .to eq('job-42')
      end
    end
  end
end
